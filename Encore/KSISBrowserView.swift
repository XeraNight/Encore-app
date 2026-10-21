import SwiftUI
import SwiftData
import WebKit
import Combine
import OSLog

// MARK: - KSIS in the app
/// KSIS inside Encore. The dancer browses KSIS as in Safari (and passes its check as a person). After each
/// page loads, the panel below says what that page means for the linked couple and offers one action:
/// link the couple, save the history, a result or the crosses, put a registration into Plán.
/// The app never opens KSIS pages on its own and never refreshes in the background: pulling the page
/// down is the live view on competition day (docs/KSIS_SAMPLES_NEEDED.md §1).
struct KSISBrowserView: View {
    static let host = "szts.ksis.eu"

    let startURL: URL

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var web = KSISWebController()
    @ObservedObject private var manager = CompetitionManager.shared

    @State private var state: ReadState = .idle
    @State private var consent = false
    @State private var isSaving = false
    @State private var notice: String?
    @State private var isPanelExpanded = true
    @State private var panelContentHeight: CGFloat = 0
    @State private var readGeneration = 0
    @State private var lastAdvancedRound: String?
    @State private var successTick = 0
    @State private var advanceTick = 0

    private enum ReadState {
        case idle
        case reading
        case reply(KSISPageReply, URL, String)
        case failed(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ZStack(alignment: .bottom) {
                KSISWebView(startURL: startURL, controller: web) { url, html in
                    pageLoaded(url: url, html: html)
                }
                .ignoresSafeArea(edges: .bottom)

                panel
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                    // The page can scroll its last rows up above the panel.
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { web.setBottomInset($0) }
            }
        }
        .background(EllegancePageBackground())
        .sensoryFeedback(.success, trigger: successTick)
        .sensoryFeedback(.impact(weight: .heavy), trigger: advanceTick)
        .preferredColorScheme(.dark)
    }

    // MARK: Top bar
    private var topBar: some View {
        HStack(spacing: 10) {
            LiquidGlassCircleButton(icon: "xmark", label: "Zavrieť", size: 40) { dismiss() }
            LiquidGlassCircleButton(icon: "chevron.left", label: "Späť", size: 40) { web.goBack() }
                .disabled(!web.canGoBack)
                .opacity(web.canGoBack ? 1 : 0.4)
            Spacer(minLength: 4)
            VStack(spacing: 1) {
                Text("KSIS")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                Text("Zdroj výsledkov: SZTŠ")
                    .font(.caption2)
                    .foregroundColor(Color.textSecondary)
            }
            Spacer(minLength: 4)
            if web.isLoading {
                ProgressView()
                    .tint(Color.gold400)
                    .frame(width: 40, height: 40)
            } else {
                LiquidGlassCircleButton(icon: "arrow.clockwise", label: "Obnoviť stránku", size: 40) { web.reload() }
            }
            LiquidGlassCircleButton(icon: "safari", label: "Otvoriť v Safari", size: 40) {
                if let url = web.currentURL { UIApplication.shared.open(url) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Panel
    private var panel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) { isPanelExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "sparkle.magnifyingglass")
                        .foregroundColor(Color.gold400)
                    Text(panelTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: isPanelExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color.textSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isPanelExpanded ? "Zbaliť panel" : "Rozbaliť panel")

            if isPanelExpanded {
                // As tall as its content (a hint is two lines), scrolling only past ~40 % of the screen.
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        panelContent
                        if let notice {
                            Text(notice)
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(Color.gold300)
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { panelContentHeight = $0 }
                }
                .frame(height: min(panelContentHeight, 320))
                .scrollBounceBehavior(.basedOnSize)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(16)
        .glassEffect(.regular.tint(Color.encoreBurgundy.opacity(0.82)), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.gold400.opacity(0.28), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: notice)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: panelContentHeight)
    }

    private var panelTitle: String {
        switch state {
        case .idle: return "Encore číta stránky KSIS"
        case .reading: return "Čítam stránku…"
        case .failed: return "Stránku sa nepodarilo prečítať"
        case .reply(let reply, _, _):
            switch reply.kind {
            case .couplesList: return "Nájdené páry"
            case .coupleDetail: return "Detail páru"
            case .couplePage: return "Stránka páru"
            case .results: return "Výsledková listina"
            case .marks: return "Hodnotenie porotcov"
            case .registrations: return "Prihlášky"
            case .blocked: return "KSIS overuje, že si človek"
            case .unsupported: return "Encore číta stránky KSIS"
            }
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        switch state {
        case .idle:
            hint("Otvor zoznam párov, stránku svojho páru, výsledky alebo hodnotenie. Appka ich rozpozná sama.")
        case .reading:
            ProgressView()
                .tint(Color.gold400)
                .frame(maxWidth: .infinity)
        case .failed(let message):
            hint(message)
        case .reply(let reply, _, _):
            switch reply.kind {
            case .couplesList: couplesList(reply)
            case .coupleDetail: coupleDetail(reply)
            case .couplePage: couplePage(reply)
            case .results: resultsPage(reply)
            case .marks: marksPage(reply)
            case .registrations: registrations(reply)
            case .blocked: hint("Dokonči overenie na stránke vyššie. Potom sa panel sám obnoví.")
            case .unsupported: hint("Otvor zoznam párov, stránku svojho páru, výsledky alebo hodnotenie. Appka ich rozpozná sama.")
            }
        }
    }

    // MARK: Kinds
    @ViewBuilder
    private func couplesList(_ reply: KSISPageReply) -> some View {
        let couples = reply.couples ?? []
        if couples.isEmpty {
            hint("Žiadny pár. Skús priezvisko alebo číslo preukazu partnera.")
        } else {
            ForEach(couples) { couple in
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(couple.partner) & \(couple.partnerka)")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                        Text("\(couple.club) · \(couple.ageCategory) · ŠTT \(couple.sttClass) · LAT \(couple.latClass)")
                            .font(.caption)
                            .foregroundColor(Color.textSecondary)
                    }
                    Spacer(minLength: 8)
                    if couple.isLinked {
                        Label("Prepojené", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Color.syncEmerald)
                    } else {
                        smallButton("Sme to my") {
                            if let url = URL(string: "https://\(Self.host)/detail_paru.php?cp=\(couple.pairNumber)") {
                                web.load(url)
                            }
                        }
                    }
                }
                .padding(12)
                .homeCard(cornerRadius: 14)
            }
        }
    }

    @ViewBuilder
    private func coupleDetail(_ reply: KSISPageReply) -> some View {
        if let couple = reply.couple {
            coupleCard(couple)
            if reply.isLinked == true {
                hint("Ďalej: otvor výsledky ktorejkoľvek súťaže, kde ste tancovali, a ťukni na svoje meno. Uložíš celú históriu aj s krížikmi.")
                primaryButton("Aktualizovať triedu a body", action: { save() })
            } else {
                Toggle(isOn: $consent) {
                    Text("Partner(ka) súhlasí, aby sme v Encore videli naše spoločné výsledky.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.85))
                }
                .tint(Color.gold500)
                primaryButton("Prepojiť pár", isEnabled: consent, action: { save() })
            }
        }
    }

    @ViewBuilder
    private func couplePage(_ reply: KSISPageReply) -> some View {
        if let couple = reply.couple {
            coupleCard(couple)
        }
        if reply.isOwn == true {
            primaryButton("Uložiť históriu (\(reply.competitions ?? 0) súťaží)", action: { save() })
        } else if reply.isLinked == true {
            hint("Toto nie je stránka tvojho prepojeného páru.")
        } else {
            hint("Najprv prepoj svoj pár: vyhľadaj ho v zozname párov a ťukni Sme to my.")
        }
    }

    @ViewBuilder
    private func resultsPage(_ reply: KSISPageReply) -> some View {
        if let competition = reply.competition {
            competitionHeader(competition)
            if let own = reply.own {
                HStack(spacing: 8) {
                    statPill(own.place.map { "\($0.display) z \(competition.couples ?? 0)" } ?? "–", caption: "miesto")
                    statPill(own.points.map { "+\($0)" } ?? "–", caption: "body")
                    if let total = own.total { statPill("\(total.points)/\(total.finals)F", caption: "spolu") }
                }
                primaryButton("Uložiť výsledok", action: { save() })
                secondaryButton("Hodnotenie porotcov") { openMarks(competition.sutazId) }
            } else {
                hint(manager.couples.isEmpty
                     ? "Najprv prepoj svoj pár, potom appka nájde jeho výsledok."
                     : "Tvoj prepojený pár v tejto súťaži nie je.")
            }
        }
    }

    @ViewBuilder
    private func marksPage(_ reply: KSISPageReply) -> some View {
        if reply.needsDefaultView == true, let raw = reply.defaultUrl, let url = URL(string: raw) {
            hint("Toto zobrazenie appka nečíta. Prepni na základné hodnotenie.")
            primaryButton("Základné hodnotenie") { web.load(url) }
        } else if let competition = reply.competition {
            competitionHeader(competition)
            if let rounds = reply.rounds, !rounds.isEmpty {
                if let latest = rounds.last, latest.advanced == true {
                    Label("Postupujete ďalej po kole \(latest.round)", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color.syncEmerald)
                }
                ForEach(rounds) { round in
                    KSISRoundSummaryRow(round: round)
                }
                primaryButton("Uložiť krížiky do denníka", action: { save() })
                hint("Počas súťaže potiahni stránku nadol. Keď KSIS zverejní ďalšie kolo, uvidíš ho tu.")
            } else {
                hint(manager.couples.isEmpty
                     ? "Najprv prepoj svoj pár, potom appka nájde jeho krížiky."
                     : "Tvoj prepojený pár v tomto hodnotení zatiaľ nie je. Počas súťaže potiahni stránku nadol a skús znova.")
            }
        }
    }

    @ViewBuilder
    private func registrations(_ reply: KSISPageReply) -> some View {
        if let event = reply.event {
            Text(event.name)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
            if let categories = reply.categories, !categories.isEmpty {
                Text("Ste prihlásení: \(categories.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.85))
                if event.date.flatMap({ Self.isoDay.date(from: $0) }) != nil {
                    primaryButton("Pridať do kalendára") { addToPlan(event: event, categories: categories) }
                } else {
                    // Without a date it would land on today; better to add it by hand with the right day.
                    hint("KSIS tu neuvádza dátum súťaže. Pridaj ju v Kalendári s dátumom ručne.")
                }
            } else {
                hint(reply.isLinked == true
                     ? "Tvoj prepojený pár tu prihlásený nie je."
                     : "Prepoj svoj pár a appka tu nájde vaše kategórie.")
            }
        }
    }

    // MARK: Pieces
    private func coupleCard(_ couple: KSISPageReply.PageCouple) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(couple.partner) & \(couple.partnerka)")
                .font(.headline)
                .foregroundColor(.white)
            Text([couple.club, couple.ageCategory].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption)
                .foregroundColor(Color.textSecondary)
            HStack(spacing: 8) {
                standingPill("ŠTT", couple.stt)
                standingPill("LAT", couple.lat)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 14)
    }

    private func standingPill(_ label: String, _ standing: KSISPageReply.PageStanding?) -> some View {
        var parts = ["\(label) \(standing?.className ?? "–")"]
        if let points = standing?.resolvedPoints { parts.append("\(points) b") }
        if let finals = standing?.resolvedFinals { parts.append("\(finals) F") }
        return Text(parts.joined(separator: " · "))
            .font(.caption.weight(.bold))
            .foregroundColor(Color.gold300)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.gold500.opacity(0.14), in: Capsule())
    }

    private func competitionHeader(_ competition: KSISPageReply.Competition) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(competition.category)
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
            Text([competition.eventName, competition.date.flatMap { Self.displayDate($0) }].compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundColor(Color.textSecondary)
        }
    }

    private func statPill(_ value: String, caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundColor(.white)
            Text(caption)
                .font(.caption2)
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .homeCard(cornerRadius: 12)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(.white.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func primaryButton(_ title: String, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        PrimarySheetButton(title: title, isLoading: isSaving, isEnabled: isEnabled, action: action)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color.gold400)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    private func smallButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(Color.obsidian900)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .background(Color.gold400, in: Capsule())
        }
        .buttonStyle(.pressable)
    }

    // MARK: Actions
    private func pageLoaded(url: URL, html: String) {
        readGeneration += 1
        let generation = readGeneration
        notice = nil
        state = .reading
        Task {
            do {
                let reply = try await manager.read(url: url, html: html)
                guard generation == readGeneration else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { state = .reply(reply, url, html) }
                noteAdvancement(reply)
            } catch {
                guard generation == readGeneration else { return }
                state = .failed(error.localizedDescription)
            }
        }
    }

    /// A new "Postup Y" for the couple gets a strong tap, once per round.
    private func noteAdvancement(_ reply: KSISPageReply) {
        guard reply.kind == .marks, let latest = reply.rounds?.last, latest.advanced == true,
              lastAdvancedRound != latest.round else { return }
        lastAdvancedRound = latest.round
        advanceTick += 1
    }

    private func save() {
        guard case .reply(_, let url, let html) = state, !isSaving else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let reply = try await manager.save(url: url, html: html, consent: consent)
                state = .reply(reply, url, html)
                successTick += 1
                notice = savedMessage(reply)
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    private func savedMessage(_ reply: KSISPageReply) -> String {
        switch reply.kind {
        case .coupleDetail: return "Pár je prepojený, trieda a body sú aktuálne."
        case .couplePage: return "História je v denníku: \(reply.saved ?? 0) súťaží."
        case .results: return "Výsledok je v denníku."
        case .marks: return "Krížiky sú v denníku."
        default: return "Uložené."
        }
    }

    private func openMarks(_ sutazId: Int?) {
        guard let sutazId, let url = URL(string: "https://\(Self.host)/hodnot_sut.php?sutaz_id=\(sutazId)") else { return }
        web.load(url)
    }

    private func addToPlan(event: KSISPageReply.Event, categories: [String]) {
        guard let date = event.date.flatMap({ Self.isoDay.date(from: $0) }) else { return }
        let name = event.name
        let sameName = (try? modelContext.fetch(FetchDescriptor<PlannedCompetition>(predicate: #Predicate { $0.name == name }))) ?? []
        if let existing = sameName.first(where: { PlannerCalendar.calendar.isDate($0.date, inSameDayAs: date) }) {
            existing.targetCategories = categories
            existing.intent = .going
        } else {
            let competition = PlannedCompetition(name: name, city: event.venue ?? "", date: date)
            competition.targetCategories = categories
            competition.intent = .going
            modelContext.insert(competition)
        }
        try? modelContext.save()
        successTick += 1
        notice = "Súťaž je v kalendári aj s vašimi kategóriami."
    }

    // MARK: Dates
    private static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// "12. septembra 2026", or "12. 9. 2026" where space is short.
    static func displayDate(_ iso: String, numeric: Bool = false) -> String? {
        let style = Date.FormatStyle.dateTime.day().month(numeric ? .defaultDigits : .wide).year()
        return isoDay.date(from: iso)?.formatted(style.locale(Locale(identifier: "sk")))
    }

    /// Couples list search: a number goes to "Č.pr", anything else to the name search.
    static func searchURL(for query: String) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var components = URLComponents(string: "https://\(host)/menu.php")
        var items = [URLQueryItem(name: "akcia", value: "CZP"), URLQueryItem(name: "aktivne", value: "on")]
        if !trimmed.isEmpty {
            items.append(URLQueryItem(name: trimmed.allSatisfy(\.isNumber) ? "cis_pr" : "hladany_text", value: trimmed))
        }
        components?.queryItems = items
        return components?.url
    }
}

// MARK: - One round in a line
/// "1. kolo · 28 · 1.–2. · postup ✓" with the crosses per dance below.
struct KSISRoundSummaryRow: View {
    let round: KSISRound

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(round.round)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Spacer(minLength: 4)
                Text(round.isFinal ? "Suma \(round.sumText)" : "\(round.sumText) krížikov")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundColor(Color.gold300)
                if let place = round.place {
                    Text(place.display)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.8))
                }
                if let advanced = round.advanced {
                    Image(systemName: advanced ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(advanced ? Color.syncEmerald : Color.latinRed)
                        .accessibilityLabel(advanced ? "Postup" : "Bez postupu")
                }
            }
            if !round.isFinal {
                Text(round.dances.map { "\($0.dance.capitalized) \($0.crosses ?? 0)" }.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundColor(Color.textSecondary)
            }
        }
        .padding(10)
        .homeCard(cornerRadius: 12)
    }
}

// MARK: - Web view
@MainActor
final class KSISWebController: ObservableObject {
    @Published var canGoBack = false
    @Published var isLoading = false
    @Published var currentURL: URL?
    weak var webView: WKWebView?

    func load(_ url: URL) { webView?.load(URLRequest(url: url)) }
    func reload() { webView?.reload() }
    func goBack() { webView?.goBack() }

    /// Room under the page for the panel that floats over it.
    func setBottomInset(_ height: CGFloat) {
        guard let scrollView = webView?.scrollView, abs(scrollView.contentInset.bottom - height) > 1 else { return }
        scrollView.contentInset.bottom = height
        scrollView.verticalScrollIndicatorInsets.bottom = height
    }

    /// KSIS's couple detail is a desktop pop-up with 8-point text; only that page is shown larger.
    static func pageZoom(for url: URL) -> CGFloat {
        url.path.hasSuffix("detail_paru.php") ? 1.5 : 1
    }
}

struct KSISWebView: UIViewRepresentable {
    let startURL: URL
    let controller: KSISWebController
    let onPageLoaded: (URL, String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller, onPageLoaded: onPageLoaded) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.applicationNameForUserAgent = "EncoreApp/1.0"
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.pullToRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
        controller.webView = webView
        webView.load(URLRequest(url: startURL))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onPageLoaded = onPageLoaded
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let controller: KSISWebController
        var onPageLoaded: (URL, String) -> Void

        init(controller: KSISWebController, onPageLoaded: @escaping (URL, String) -> Void) {
            self.controller = controller
            self.onPageLoaded = onPageLoaded
        }

        @objc func pullToRefresh() {
            controller.reload()
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url, let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else { return .allow }
            // Pages for other frames (e.g. the Cloudflare check) load as they want.
            guard navigationAction.targetFrame?.isMainFrame ?? true else { return .allow }
            guard url.host?.lowercased() == KSISBrowserView.host else {
                await UIApplication.shared.open(url)
                return .cancel
            }
            if navigationAction.targetFrame == nil {   // "open in new window" stays in this view
                webView.load(navigationAction.request)
                return .cancel
            }
            webView.pageZoom = KSISWebController.pageZoom(for: url)
            return .allow
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            controller.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            finished(webView)
            guard let url = webView.url, url.host?.lowercased() == KSISBrowserView.host else { return }
            Task { @MainActor in
                do {
                    if let html = try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String {
                        onPageLoaded(url, html)
                    }
                } catch {
                    Logger.sync.error("Reading KSIS page failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            finished(webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            finished(webView)
        }

        private func finished(_ webView: WKWebView) {
            controller.isLoading = false
            controller.canGoBack = webView.canGoBack
            controller.currentURL = webView.url
            webView.scrollView.refreshControl?.endRefreshing()
        }
    }
}
