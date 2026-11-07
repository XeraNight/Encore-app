import SwiftUI
import OSLog

// MARK: - One update from KSIS
/// What one tap reads from KSIS.
enum KSISUpdateJob: String, Identifiable {
    /// Couples, points, every competition, the crosses still missing, the cup and the calendar.
    case everything
    /// The competition calendar alone.
    case calendar

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
        case finished(String)
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

    private let manager = CompetitionManager.shared
    private var task: Task<Void, Never>?
    private var pageWaiter: CheckedContinuation<Page, Error>?
    private var consentWaiter: CheckedContinuation<Bool, Never>?
    private var lastLabel = "Otváram KSIS…"
    /// Pages that could not be saved, for the last line.
    private var failures = 0
    private var isClosed = false

    init(job: KSISUpdateJob) {
        self.job = job
    }

    /// The first page. Nil only without a dancer, and the update is not offered then.
    var startURL: URL? {
        switch job {
        case .calendar: return KSISEvent.calendarURL()
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

    /// The window closed: what is saved stays, the next update goes on from there.
    func cancel() {
        isClosed = true
        task?.cancel()
        pageWaiter?.resume(throwing: CancellationError())
        pageWaiter = nil
        answerNewCouples(save: false)
    }

    // MARK: The run
    private func run(first: Page) async {
        do {
            switch job {
            case .calendar:
                try rememberCalendar(first)
                phase = .finished("Kalendár je aktuálny.")
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
        await manager.loadAllData()
        try await updatePointsAndHistory()
        await manager.loadAllData()
        let marksLeft = try await updateMarks()
        await manager.loadAllData()
        try await updateCup()

        say("Kalendár súťaží…")
        do {
            if let url = KSISEvent.calendarURL() { try rememberCalendar(try await open(url)) }
        } catch KSISCalendarPage.Failure.layoutChanged {
            failures += 1
        }

        let newResults = manager.results.count - resultsBefore
        let newMarks = manager.results.filter { $0.rounds?.isEmpty == false }.count - marksBefore
        phase = .finished(summary(newResults: newResults, newMarks: newMarks, marksLeft: marksLeft))
    }

    /// The dancer's couples in KSIS, the ended ones too, recognised by the server from the dancer's KSIS number and name.
    private func updateCouples(_ page: Page) async throws {
        say("Hľadám vaše páry…")
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

    /// Class and points of the current couple, then every competition of every couple. A couple that ended keeps
    /// only its history: its pair number can belong to a new couple by now.
    private func updatePointsAndHistory() async throws {
        if let pair = manager.activeCouple?.pairNumber, let url = KSISBrowserView.coupleDetail(pair) {
            say("Triedy a body…")
            try await save(try await open(url))
        }
        let histories = manager.couples.compactMap(\.coupleId)
        for (index, coupleId) in histories.enumerated() {
            say(histories.count == 1 ? "História súťaží…" : "História súťaží, pár \(index + 1) z \(histories.count)…")
            if let url = KSISBrowserView.page("par.php?id=\(coupleId)") {
                try await save(try await open(url))
            }
        }
    }

    /// Crosses of the competitions without them, newest first. Returns how many are left for the next update.
    private func updateMarks() async throws -> Int {
        let missing = manager.results.filter(manager.isMissingMarks)
        let batch = missing.prefix(Self.marksPerRun)
        for (index, result) in batch.enumerated() {
            say("Krížiky \(index + 1) z \(batch.count)…")
            guard let url = KSISBrowserView.page("hodnot_sut.php?sutaz_id=\(result.sutazId)") else { continue }
            let page = try await open(url)
            do {
                _ = try await manager.save(url: page.url, html: page.html, reloads: false)
            } catch CompetitionManager.ActionError.notFound {
                manager.noteNoMarks(result)
            } catch CompetitionManager.ActionError.server {
                failures += 1
            }
        }
        return missing.count - batch.count
    }

    private func updateCup() async throws {
        guard let couple = manager.activeCouple, let group = SlovakCup.Group(ageCategory: couple.ageCategory) else { return }
        let year = Calendar.current.component(.year, from: Date())
        for discipline in SlovakCup.disciplines(for: couple) {
            say("Slovenský pohár \(discipline.title)…")
            guard let url = SlovakCup.standingsURL(year: year, group: group, discipline: discipline) else { continue }
            let page = try await open(url)
            do {
                if let standings = try await manager.read(url: page.url, html: page.html).standings {
                    SlovakCupStore.shared.remember(standings)
                }
            } catch CompetitionManager.ActionError.server {
                failures += 1
            }
        }
    }

    // MARK: Steps
    private func say(_ label: String) {
        lastLabel = label
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
    private func save(_ page: Page, consent: Bool = false) async throws {
        do {
            _ = try await manager.save(url: page.url, html: page.html, consent: consent, reloads: false)
        } catch CompetitionManager.ActionError.server, CompetitionManager.ActionError.notFound {
            failures += 1
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
        var text = lines.isEmpty ? "Všetko je aktuálne." : "Uložené: \(lines.joined(separator: ", "))."
        if marksLeft > 0 { text += " Ďalšie krížiky načítam pri ďalšom Aktualizovať (\(marksLeft))." }
        if failures > 0 { text += " Niektoré stránky sa nepodarilo uložiť, skús to znova." }
        return text
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
        .sensoryFeedback(.success, trigger: doneTick)
        .onChange(of: run.isFinished) { _, isFinished in
            guard isFinished else { return }
            doneTick += 1
            if run.job == .calendar, case .finished = run.phase { dismiss() }
        }
        .onDisappear { run.cancel() }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            LiquidGlassCircleButton(icon: "xmark", label: "Zavrieť", size: 40) { dismiss() }
            Spacer(minLength: 4)
            VStack(spacing: 1) {
                Text(run.job == .calendar ? "Kalendár z KSIS" : "Aktualizovať z KSIS")
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
                HStack(spacing: 10) {
                    ProgressView().tint(Color.gold400)
                    Text(label)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .contentTransition(.opacity)
                }
            case .waitingForCheck:
                Label("Čakám na overenie KSIS", systemImage: "person.badge.shield.checkmark.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Text("Dokonči overenie na stránke vyššie, potom sa ukladanie samo rozbehne.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
            case .newCouples(let couples):
                newCouples(couples)
            case .finished(let text):
                Label(text, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                PrimarySheetButton(title: "Hotovo", isLoading: false, isEnabled: true) { dismiss() }
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
        PrimarySheetButton(title: "Uložiť", isLoading: false, isEnabled: consent) { run.answerNewCouples(save: true) }
        Button("Preskočiť") { run.answerNewCouples(save: false) }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(Color.gold400)
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.pressable)
    }
}
