import SwiftUI
import OSLog

// MARK: - One update from KSIS
/// What one tap reads from KSIS.
enum KSISUpdateJob: String, Identifiable {
    /// Couples, points, every competition, the crosses still missing, the cup and the calendar.
    case everything
    /// The competition calendar alone.
    case calendar
    /// The next crosses still missing, nothing else.
    case marks

    var id: String { rawValue }
}

/// Goes through the KSIS pages one at a time in a window the dancer sees, and only after their tap. When KSIS shows
/// its check, the dancer passes it in that window and the run goes on; nothing here tries to get around it.
@MainActor
@Observable
final class KSISUpdateRun {
    enum Phase {
        case reading(String)
        case waitingForCheck
        /// Couples of this dancer not saved yet: saving them needs the partner's yes.
        case newCouples([KSISPageReply.ListedCouple])
        /// The dancer's earlier couples found by name: each one is ticked, a namesake abroad is unticked by hand.
        case foundCouples([KSISPageReply.FoundCouple])
        /// What was saved, and how many competitions still have crosses to read.
        case finished(String, marksLeft: Int)
        case failed(String)
    }

    private struct Page {
        let url: URL
        let html: String
    }

    /// Crosses read in one update; the next update goes on with the rest.
    private static let marksPerRun = 30
    /// A pause between pages, so KSIS sees a person's pace and not a burst.
    private static let pause = Duration.milliseconds(700)

    let job: KSISUpdateJob
    let web = KSISWebController()
    private(set) var phase: Phase = .reading("Otváram KSIS…")
    /// Which step the update is on and how far, for the panel.
    private(set) var progress: KSISReadingProgress

    private let manager = CompetitionManager.shared
    private var task: Task<Void, Never>?
    private var pageWaiter: CheckedContinuation<Page, Error>?
    private var consentWaiter: CheckedContinuation<Bool, Never>?
    /// The ticked couples, or nil when the dancer skipped the question.
    private var foundWaiter: CheckedContinuation<[Int]?, Never>?
    /// The found couples the dancer keeps ticked.
    var ticked: Set<Int> = []
    private var lastLabel = "Otváram KSIS…"
    /// What could not be read or saved, for the last line.
    private var problems = KSISUpdateProblems()
    private var isClosed = false

    init(job: KSISUpdateJob) {
        self.job = job
        self.progress = KSISReadingProgress(stage: KSISReadingProgress.stages(for: job).first ?? .couples)
        // Without a dancer there is no first page; saying so beats a spinner that never ends.
        if startURL == nil { phase = .failed("Najprv sa nájdi v KSIS: v zozname členov ťukni Som to ja pri svojom mene.") }
    }

    /// The first page. Nil only without a dancer, and the update is not offered then.
    var startURL: URL? {
        switch job {
        case .calendar: return KSISEvent.calendarURL()
        case .marks: return KSISBrowserView.page("menu.php?akcia=S")
        case .everything:
            return manager.dancer.flatMap { KSISBrowserView.couplesURL(surname: KSISBrowserView.surname(of: $0.name)) }
        }
    }

    var isFinished: Bool {
        switch phase {
        case .finished, .failed: return true
        default: return false
        }
    }

    /// The page takes taps only for KSIS's check: a link tapped during the run would be read in place of the next page.
    var isWaitingForCheck: Bool {
        if case .waitingForCheck = phase { return true }
        return false
    }

    // MARK: Pages arriving from the web view
    func pageLoaded(url: URL, html: String) {
        guard !isClosed else { return }
        if KSISCalendarPage.isChallengePage(html) {
            phase = .waitingForCheck
            return
        }
        let page = Page(url: url, html: html)
        if let pageWaiter {
            self.pageWaiter = nil
            phase = .reading(lastLabel)
            pageWaiter.resume(returning: page)
        } else if task == nil {
            task = Task { await run(first: page) }
        }
    }

    func pageFailed() {
        if let pageWaiter {
            self.pageWaiter = nil
            pageWaiter.resume(throwing: CompetitionManager.ActionError.network)
        } else if task == nil {
            phase = .failed(CompetitionManager.ActionError.network.localizedDescription)
        }
    }

    func answerNewCouples(save: Bool) {
        consentWaiter?.resume(returning: save)
        consentWaiter = nil
    }

    func answerFoundCouples(save: Bool) {
        foundWaiter?.resume(returning: save ? Array(ticked) : nil)
        foundWaiter = nil
    }

    /// The next crosses, without reading the rest again.
    func readMoreMarks() {
        guard isFinished else { return }
        problems = KSISUpdateProblems()
        task = Task {
            do {
                try await readMarks()
            } catch is CancellationError {
                // Closed by the dancer.
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    /// The window closed: what is saved stays, the next update goes on from there.
    func cancel() {
        isClosed = true
        task?.cancel()
        pageWaiter?.resume(throwing: CancellationError())
        pageWaiter = nil
        answerNewCouples(save: false)
        answerFoundCouples(save: false)
    }

    // MARK: The run
    private func run(first: Page) async {
        do {
            switch job {
            case .calendar:
                try rememberCalendar(first)
                phase = .finished("Kalendár je aktuálny.", marksLeft: 0)
            case .marks:
                try await readMarks()
            case .everything:
                try await updateEverything(first: first)
            }
        } catch is CancellationError {
            // Closed by the dancer.
        } catch KSISCalendarPage.Failure.layoutChanged {
            phase = .failed("KSIS zmenil stránku kalendára. Ostáva posledný načítaný.")
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func updateEverything(first: Page) async throws {
        let resultsBefore = manager.results.count
        let marksBefore = manager.results.filter { $0.rounds?.isEmpty == false }.count

        try await updateCouples(first)
        try await updateAllCouples()
        await manager.loadAllData()
        try await updatePointsAndHistory()
        await manager.loadAllData()
        let marksLeft = try await updateMarks()
        await manager.loadAllData()
        try await updateCup()

        say("Kalendár súťaží…", stage: .calendar)
        do {
            if let url = KSISEvent.calendarURL() { try rememberCalendar(try await open(url)) }
        } catch KSISCalendarPage.Failure.layoutChanged {
            problems.note("KSIS zmenil stránku kalendára, ostáva posledný načítaný.")
        }

        let newResults = manager.results.count - resultsBefore
        let newMarks = manager.results.filter { $0.rounds?.isEmpty == false }.count - marksBefore
        phase = .finished(summary(newResults: newResults, newMarks: newMarks, marksLeft: marksLeft), marksLeft: marksLeft)
    }

    /// The dancer's couples in KSIS, the ended ones too, recognised by the server from the dancer's KSIS number and name.
    private func updateCouples(_ page: Page) async throws {
        say("Hľadám vaše páry…", stage: .couples)
        let mine = (try await manager.read(url: page.url, html: page.html).couples ?? []).filter(\.isMine)
        guard !mine.isEmpty else { return }
        let new = mine.filter { !$0.isLinked }
        if new.isEmpty {
            try await save(page)
        } else if await askAboutNewCouples(new) {
            try await save(page, consent: true)
        }
        try Task.checkCancellation()
    }

    private func askAboutNewCouples(_ couples: [KSISPageReply.ListedCouple]) async -> Bool {
        phase = .newCouples(couples)
        return await withCheckedContinuation { consentWaiter = $0 }
    }

    private func readMarks() async throws {
        let marksBefore = manager.results.filter { $0.rounds?.isEmpty == false }.count
        let marksLeft = try await updateMarks()
        await manager.loadAllData()
        let newMarks = manager.results.filter { $0.rounds?.isEmpty == false }.count - marksBefore
        phase = .finished(summary(newResults: 0, newMarks: newMarks, marksLeft: marksLeft), marksLeft: marksLeft)
    }

    /// Every couple the dancer ever had, each with its KSIS id. The couples list keeps only the current partnerka
    /// under a pair number and no id at all; KSIS's search by name keeps them all. The server saves the dancer's
    /// couples it already knows, and new ones only when ticked here.
    private func updateAllCouples() async throws {
        guard let dancer = manager.dancer else { return }
        try await searchCouples(surname: KSISBrowserView.surname(of: dancer.name), otherName: nil, of: dancer)
        // Couples danced under another surname (a maiden name) are found under that one.
        if let other = KSISOtherSurname.get(for: dancer.personNumber) {
            let given = dancer.name.split(separator: " ").dropFirst().joined(separator: " ")
            try await searchCouples(surname: other, otherName: given.isEmpty ? other : "\(other) \(given)", of: dancer)
        }
    }

    private func searchCouples(surname: String, otherName: String?, of dancer: KSISDancer) async throws {
        guard let url = KSISBrowserView.nameSearchURL(surname) else { return }
        say("Hľadám všetky vaše páry…", stage: .couples)
        let page = try await open(url)
        let found: [KSISPageReply.FoundCouple]
        do {
            found = try await manager.read(url: page.url, html: page.html, otherName: otherName).found ?? []
        } catch CompetitionManager.ActionError.server(let message) {
            problems.note(message)
            return
        }
        let notMine = KSISNotMine.ids(for: dancer.personNumber)
        let new = found.filter { $0.isNew && !notMine.contains($0.parId) }
        let answer = new.isEmpty ? [] : await askAboutFoundCouples(new)
        let picked = answer ?? []
        if let answer {
            KSISNotMine.add(Set(new.map(\.parId)).subtracting(answer), for: dancer.personNumber)
        }
        guard !picked.isEmpty || found.contains(where: { $0.status == "claim" || $0.status == "same" }) else { return }
        try await save(page, consent: !picked.isEmpty, parIds: picked, otherName: otherName)
        try Task.checkCancellation()
    }

    private func askAboutFoundCouples(_ couples: [KSISPageReply.FoundCouple]) async -> [Int]? {
        ticked = Set(couples.map(\.parId))
        phase = .foundCouples(couples)
        return await withCheckedContinuation { foundWaiter = $0 }
    }

    /// Class and points of the current couple, then every competition of every couple. A couple that ended keeps
    /// only its history: its pair number can belong to a new couple by now.
    private func updatePointsAndHistory() async throws {
        if let pair = manager.activeCouple?.pairNumber, let url = KSISBrowserView.coupleDetail(pair) {
            say("Triedy a body…", stage: .history)
            try await save(try await open(url))
        }
        let histories = manager.couples.compactMap(\.coupleId)
        for (index, coupleId) in histories.enumerated() {
            say(histories.count == 1 ? "História súťaží…" : "História súťaží, pár \(index + 1) z \(histories.count)…",
                stage: .history, done: index, of: histories.count)
            if let url = KSISBrowserView.page("par.php?id=\(coupleId)") {
                try await save(try await open(url))
            }
        }
    }

    /// Crosses of the competitions without them and the place of those saved without one, newest first. Returns how
    /// many are left for the next update.
    private func updateMarks() async throws -> Int {
        let missing = manager.results.filter { manager.isMissingMarks($0) || manager.isMissingVenue($0) }
        let batch = missing.prefix(Self.marksPerRun)
        for (index, result) in batch.enumerated() {
            say("Krížiky a miesta \(index + 1) z \(batch.count)…", stage: .marks, done: index, of: batch.count)
            var outcome = SavedPage.notThere
            // The crosses page carries the place too. A competition KSIS has no crosses for keeps its place on
            // the results page.
            if result.rounds?.isEmpty == false || manager.isMissingMarks(result) {
                outcome = try await savePage("hodnot_sut.php?sutaz_id=\(result.sutazId)", expecting: .marks)
                if case .notThere = outcome { manager.noteNoMarks(result) }
            }
            if case .notThere = outcome, manager.isMissingVenue(result) {
                outcome = try await savePage("sutaz.php?sutaz_id=\(result.sutazId)", expecting: .results)
            }
            switch outcome {
            case .saved(venue: .none), .notThere:
                if manager.isMissingVenue(result) { manager.noteNoVenue(result) }
            case .saved, .failed:
                break
            }
        }
        return missing.count - batch.count
    }

    private enum SavedPage {
        case saved(venue: String?)
        /// The couple is not on the page.
        case notThere
        /// Not saved this time; the next update asks again.
        case failed
    }

    private func savePage(_ path: String, expecting kind: KSISPageReply.Kind) async throws -> SavedPage {
        guard let url = KSISBrowserView.page(path) else { return .failed }
        let page = try await open(url)
        do {
            let reply = try await manager.save(url: page.url, html: page.html, reloads: false)
            // A redirect or a check page in place of the one asked for says nothing about the competition: it is not
            // remembered as one KSIS has no crosses or place for, the next update asks again.
            guard reply.kind == kind else {
                problems.note("KSIS poslal inú stránku, než sa žiadala. Skús to o chvíľu znova.")
                return .failed
            }
            return .saved(venue: reply.competition?.venue)
        } catch CompetitionManager.ActionError.notFound {
            return .notThere
        } catch CompetitionManager.ActionError.server(let message) {
            problems.note(message)
            return .failed
        }
    }

    private func updateCup() async throws {
        guard let couple = manager.activeCouple, let group = SlovakCup.Group(ageCategory: couple.ageCategory) else { return }
        let disciplines = SlovakCup.disciplines(for: couple)
        for (index, discipline) in disciplines.enumerated() {
            say("Slovenský pohár \(discipline.title)…", stage: .cup, done: index, of: disciplines.count)
            guard let url = SlovakCup.standingsURL(group: group, discipline: discipline) else { continue }
            let page = try await open(url)
            do {
                if let standings = try await manager.read(url: page.url, html: page.html).standings {
                    SlovakCupStore.shared.remember(standings)
                }
            } catch CompetitionManager.ActionError.server(let message) {
                problems.note(message)
            }
        }
    }

    // MARK: Steps
    private func say(_ label: String, stage: KSISReadingProgress.Stage, done: Int? = nil, of total: Int? = nil) {
        lastLabel = label
        if progress.stage == stage {
            progress.done = done
            progress.total = total
        } else {
            progress = KSISReadingProgress(stage: stage, done: done, total: total)
        }
        phase = .reading(label)
    }

    private func open(_ url: URL) async throws -> Page {
        try await Task.sleep(for: Self.pause)
        return try await withCheckedThrowingContinuation { continuation in
            pageWaiter = continuation
            web.load(url)
        }
    }

    /// One page that cannot be saved does not stop the rest; without internet nothing can go on.
    private func save(_ page: Page, consent: Bool = false, parIds: [Int]? = nil, otherName: String? = nil) async throws {
        do {
            _ = try await manager.save(url: page.url, html: page.html, consent: consent, parIds: parIds, otherName: otherName,
                                       reloads: false)
        } catch CompetitionManager.ActionError.server(let message), CompetitionManager.ActionError.notFound(let message) {
            problems.note(message)
            Logger.sync.error("KSIS update: page not saved")
        }
    }

    private func rememberCalendar(_ page: Page) throws {
        KSISCalendarStore.shared.remember(try KSISCalendarPage.parse(page.html))
    }

    private func summary(newResults: Int, newMarks: Int, marksLeft: Int) -> String {
        var lines: [String] = []
        if newResults > 0 { lines.append(slovakCount(newResults, one: "nová súťaž", few: "nové súťaže", many: "nových súťaží")) }
        if newMarks > 0 { lines.append("krížiky k \(slovakCount(newMarks, one: "súťaži", few: "súťažiam", many: "súťažiam"))") }
        let withoutHistory = manager.couples.filter { $0.coupleId == nil }.count
        let nothingToSay = withoutHistory > 0 || marksLeft > 0 || problems.sentence != nil
        var text = lines.isEmpty ? (nothingToSay ? "" : "Všetko je aktuálne.") : "Uložené: \(lines.joined(separator: ", ")). "
        if withoutHistory > 0 {
            text += "História chýba pri \(slovakCount(withoutHistory, one: "páre", few: "pároch", many: "pároch")), pozri Moje výsledky."
        }
        if let sentence = problems.sentence { text += " \(sentence)" }
        return text.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - What went wrong
/// What could not be read or saved in one update, each message once and at most two in the last line, so the dancer
/// is told which page and why, not only that "some pages" failed.
struct KSISUpdateProblems: Equatable {
    private(set) var messages: [String] = []

    mutating func note(_ message: String) {
        if !messages.contains(message) { messages.append(message) }
    }

    var sentence: String? {
        messages.isEmpty ? nil : "Nepodarilo sa: " + messages.prefix(2).joined(separator: " ")
    }
}

// MARK: - Namesakes
/// Couples on the KSIS search the dancer said are not theirs: the search shows names, not personal numbers, so a
/// namesake abroad looks the same. Kept on this iPhone for the dancer's KSIS number and never asked about again.
enum KSISNotMine {
    private static func key(_ personNumber: Int) -> String { "encore.ksis.notMine.\(personNumber)" }

    static func ids(for personNumber: Int) -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: key(personNumber)) as? [Int] ?? [])
    }

    static func add(_ parIds: Set<Int>, for personNumber: Int) {
        guard !parIds.isEmpty else { return }
        UserDefaults.standard.set(Array(ids(for: personNumber).union(parIds)), forKey: key(personNumber))
    }
}

/// Another surname the dancer competed under in KSIS (a maiden name), so Aktualizovať finds those couples too. Kept on
/// this iPhone for the dancer's KSIS number.
enum KSISOtherSurname {
    private static func key(_ personNumber: Int) -> String { "encore.ksis.otherSurname.\(personNumber)" }

    static func get(for personNumber: Int) -> String? {
        UserDefaults.standard.string(forKey: key(personNumber)).flatMap { $0.isEmpty ? nil : $0 }
    }

    static func set(_ surname: String, for personNumber: Int) {
        let trimmed = surname.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key(personNumber))
        } else {
            UserDefaults.standard.set(trimmed, forKey: key(personNumber))
        }
    }
}

// MARK: - The window
/// KSIS as it is, with one panel saying what is being read. Closing it keeps what is saved.
struct KSISUpdateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var run: KSISUpdateRun
    @State private var consent = false
    @State private var doneTick = 0

    init(job: KSISUpdateJob) {
        _run = State(initialValue: KSISUpdateRun(job: job))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack(alignment: .bottom) {
                if let url = run.startURL {
                    KSISWebView(startURL: url, controller: run.web) { url, html in
                        run.pageLoaded(url: url, html: html)
                    } onPageFailed: {
                        run.pageFailed()
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(run.isWaitingForCheck)
                }
                panel
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { run.web.setBottomInset($0) }
            }
        }
        .background(EllegancePageBackground())
        // A light runs round the edge while the update reads, so it is plain that something long is going on.
        .overlay { EncoreEdgeGlow(isActive: isReading) }
        .sensoryFeedback(.success, trigger: doneTick)
        .onChange(of: run.isFinished) { _, isFinished in
            guard isFinished else { return }
            doneTick += 1
            if run.job == .calendar, case .finished = run.phase { dismiss() }
        }
        .onDisappear { run.cancel() }
        .preferredColorScheme(.dark)
    }

    private var isReading: Bool {
        if case .reading = run.phase { return true }
        return false
    }

    private var title: String {
        switch run.job {
        case .calendar: return "Kalendár z KSIS"
        case .marks: return "Krížiky z KSIS"
        case .everything: return "Aktualizovať z KSIS"
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            LiquidGlassCircleButton(icon: "xmark", label: "Zavrieť", size: 40) { dismiss() }
            Spacer(minLength: 4)
            VStack(spacing: 1) {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                Text("Zdroj výsledkov: SZTŠ")
                    .font(.caption2)
                    .foregroundColor(Color.textSecondary)
            }
            Spacer(minLength: 4)
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch run.phase {
            case .reading(let label):
                KSISReadingPanel(label: label, progress: run.progress, stages: KSISReadingProgress.stages(for: run.job))
            case .waitingForCheck:
                Label("Čakám na overenie KSIS", systemImage: "person.badge.shield.checkmark.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Text("Dokonči overenie na stránke vyššie, potom sa ukladanie samo rozbehne.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
            case .newCouples(let couples):
                newCouples(couples)
            case .foundCouples(let couples):
                foundCouples(couples)
            case .finished(let text, let marksLeft):
                if !text.isEmpty {
                    Label(text, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if marksLeft > 0 {
                    marksLeftNote(marksLeft)
                    PrimarySheetButton(title: "Čítať ďalej", isLoading: false, isEnabled: true) { run.readMoreMarks() }
                    secondaryButton("Neskôr") { dismiss() }
                } else {
                    PrimarySheetButton(title: "Hotovo", isLoading: false, isEnabled: true) { dismiss() }
                }
            case .failed(let text):
                Text(text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                PrimarySheetButton(title: "Zavrieť", isLoading: false, isEnabled: true) { dismiss() }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .ksisPanel()
    }

    @ViewBuilder
    private func newCouples(_ couples: [KSISPageReply.ListedCouple]) -> some View {
        Text(couples.count == 1 ? "Našiel som nový pár" : "Našiel som nové páry (\(couples.count))")
            .font(.subheadline.weight(.bold))
            .foregroundColor(.white)
        ForEach(couples) { couple in
            Text("\(couple.partner) & \(couple.partnerka)\(couple.isActive ? " · aktuálny" : "")")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Color.gold300)
        }
        KSISConsentToggle(isOn: $consent)
        PrimarySheetButton(title: "Uložiť", isLoading: false, isEnabled: consent) {
            run.answerNewCouples(save: true)
            // The yes was for these couples; the ones found next are asked about on their own.
            consent = false
        }
        secondaryButton("Preskočiť") { run.answerNewCouples(save: false) }
    }

    /// The earlier couples, each ticked: a namesake abroad has the same name and is unticked by hand.
    @ViewBuilder
    private func foundCouples(_ couples: [KSISPageReply.FoundCouple]) -> some View {
        Text(couples.count == 1 ? "Našiel som ďalší pár" : "Našiel som ďalšie páry (\(couples.count))")
            .font(.subheadline.weight(.bold))
            .foregroundColor(.white)
        Text("Páry s tvojím menom, aj skončené. Odškrtni tie, ktoré nie sú tvoje, napríklad menovca z inej krajiny. Appka si to zapamätá.")
            .font(.footnote)
            .foregroundColor(.white.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
        if couples.count > 4 {
            ScrollView { foundRows(couples) }
                .frame(height: 230)
        } else {
            foundRows(couples)
        }
        KSISConsentToggle(isOn: $consent)
        PrimarySheetButton(title: run.ticked.isEmpty ? "Ani jeden nie je môj" : "Uložiť", isLoading: false,
                           isEnabled: run.ticked.isEmpty || consent) {
            run.answerFoundCouples(save: true)
        }
        secondaryButton("Preskočiť") { run.answerFoundCouples(save: false) }
    }

    private func foundRows(_ couples: [KSISPageReply.FoundCouple]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(couples) { couple in
                Toggle(isOn: tick(couple.parId)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(couple.partner) & \(couple.partnerka)")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color.gold300)
                            .lineLimit(2)
                        Text([couple.club, slovakCount(couple.competitions, one: "súťaž", few: "súťaže", many: "súťaží")]
                            .filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                    }
                }
                .tint(Color.gold400)
            }
        }
        .sensoryFeedback(.selection, trigger: run.ticked)
    }

    private func tick(_ parId: Int) -> Binding<Bool> {
        Binding {
            run.ticked.contains(parId)
        } set: { isOn in
            if isOn { run.ticked.insert(parId) } else { run.ticked.remove(parId) }
        }
    }

    /// Crosses and the place are one KSIS page per competition, read 30 at a time.
    private func marksLeftNote(_ count: Int) -> some View {
        let rounds = (count + 29) / 30
        return VStack(alignment: .leading, spacing: 3) {
            Text("Zostáva dočítať \(slovakCount(count, one: "súťaž", few: "súťaže", many: "súťaží"))")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
            Text("Číta sa po 30 súťaží, ešte \(slovakCount(rounds, one: "kolo", few: "kolá", many: "kôl")).")
                .font(.footnote)
                .foregroundColor(Color.gold300)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.encoreCrimson.opacity(0.6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.gold400.opacity(0.5), lineWidth: 0.5))
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(Color.gold400)
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.pressable)
    }
}
