import SwiftUI

// MARK: - Dancer: keys for one routine
/// Lend this routine to a guest coach for a few days. The QR code is shown once (only its hash is stored).
struct GuestCoachKeysSheet: View {
    let routine: Routine

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var service = GuestCoachService.shared

    @State private var keys: [GuestCoachKey] = []
    @State private var days = 7
    @State private var newKey: (key: GuestCoachKey, link: URL)?
    @State private var isWorking = false
    @State private var errorText: String?
    @State private var keyToRevoke: GuestCoachKey?
    @State private var successTick = 0

    private var maxDays: Int { GuestCoachLink.maxDays(for: subscriptionManager.currentTier) }
    private var dayOptions: [Int] { [7, 14, 30].filter { $0 <= maxDays } }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Požičaj túto zostavu trénerovi na seminári. Uvidí názvy figúr a rytmus, nie tvoje poznámky ani poznámky iných trénerov. Jeho poznámky ti ostanú aj po skončení kľúča.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)

                        if let newKey {
                            qrCard(newKey.link, expires: newKey.key.expiresAt)
                                .transition(.scale(scale: 0.95).combined(with: .opacity))
                        } else {
                            createCard
                        }

                        if !keys.isEmpty {
                            keysList
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Hosťujúci tréner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavrieť") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
            }
            .confirmationDialog("Zrušiť kľúč?", isPresented: Binding(
                get: { keyToRevoke != nil },
                set: { if !$0 { keyToRevoke = nil } }
            ), titleVisibility: .visible) {
                Button("Zrušiť kľúč", role: .destructive) {
                    if let key = keyToRevoke { revoke(key) }
                }
            } message: {
                Text("Tréner zostavu hneď prestane vidieť. Jeho doterajšie poznámky ti ostanú.")
            }
            .alert("Nepodarilo sa", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
            .sensoryFeedback(.success, trigger: successTick)
            .task { await reload() }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: newKey?.key.id)
        }
        .preferredColorScheme(.dark)
    }

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(title: "NOVÝ KĽÚČ", systemImage: "key.fill")
            if dayOptions.count > 1 {
                Picker("Platnosť", selection: $days) {
                    ForEach(dayOptions, id: \.self) { option in
                        Text("\(option) dní").tag(option)
                    }
                }
                .pickerStyle(.segmented)
            } else {
                Text("Platí 7 dní. Vo Free môžeš mať naraz jeden kľúč; Plus dovolí viac kľúčov a až 30 dní.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrimarySheetButton(title: "Vytvoriť kľúč", isLoading: isWorking, isEnabled: true, action: create)
        }
        .padding(16)
        .homeCard(cornerRadius: 20)
    }

    private func qrCard(_ link: URL, expires: Date) -> some View {
        VStack(spacing: 14) {
            if let image = QRGenerator.generateQRCode(from: link.absoluteString) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 220)
                    .padding(12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityLabel("QR kód kľúča")
            }
            Text("Tréner ho naskenuje v Encore: Domov → logo → Skenovať QR. Platí do \(expires.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "sk")))).")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Text("QR kód uvidíš len teraz. Keď ho stratíš, vytvor nový.")
                .font(.caption)
                .foregroundColor(Color.gold300)
            ShareLink(item: link, message: Text("Kľúč k mojej zostave v Encore")) {
                Label("Poslať odkaz", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Button("Hotovo") { newKey = nil }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color.gold400)
                .frame(minHeight: 44)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .homeCard(cornerRadius: 20)
    }

    private var keysList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "KĽÚČE", systemImage: "list.bullet", count: keys.filter(\.isActive).count)
            VStack(spacing: 0) {
                ForEach(keys) { key in
                    HStack(spacing: 12) {
                        Image(systemName: key.isActive ? "key.fill" : "key")
                            .foregroundColor(key.isActive ? Color.gold400 : .white.opacity(0.35))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(key.guestName.map { "Používa: \($0)" } ?? (key.redeemedAt == nil ? "Zatiaľ nepoužitý" : "Používa tréner"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white.opacity(key.isActive ? 1 : 0.5))
                            Text(statusText(key))
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                        }
                        Spacer()
                        if key.isActive {
                            Button("Zrušiť") { keyToRevoke = key }
                                .font(.caption.weight(.bold))
                                .foregroundColor(Color.latinRed)
                                .frame(minHeight: 44)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    if key.id != keys.last?.id { HomeRowDivider() }
                }
            }
            .homeCard(cornerRadius: 18)
        }
    }

    private func statusText(_ key: GuestCoachKey) -> String {
        let day = { (date: Date) in date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "sk"))) }
        if key.revokedAt != nil { return "Zrušený" }
        if key.expiresAt <= Date() { return "Skončil \(day(key.expiresAt))" }
        return "Platí do \(day(key.expiresAt))"
    }

    private func reload() async {
        do {
            keys = try await service.keys(for: routine.id)
        } catch {
            keys = []
        }
    }

    private func create() {
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                newKey = try await service.createKey(for: routine, days: min(days, maxDays))
                successTick += 1
                await reload()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }

    private func revoke(_ key: GuestCoachKey) {
        Task {
            do {
                try await service.revoke(key.id)
                await reload()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

// MARK: - Guest: use a key, then see the routine
/// Opened by a scanned QR code or a link. Nothing happens until the guest taps "Použiť kľúč": using the key
/// tells its owner who used it, so it must never run just because a link was opened.
struct GuestKeyRedeemView: View {
    let token: String

    @Environment(\.dismiss) private var dismiss
    @State private var access: GuestAccess?
    @State private var errorText: String?
    @State private var isRedeeming = false

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                if let access {
                    GuestRoutineView(access: access)
                } else if let errorText {
                    VStack(spacing: 12) {
                        Image(systemName: "key.slash")
                            .font(.largeTitle)
                            .foregroundColor(Color.gold400)
                        Text(errorText)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else if isRedeeming {
                    ProgressView("Overujem kľúč…")
                        .tint(Color.gold400)
                        .foregroundColor(.white)
                } else {
                    confirmation
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavrieť") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var confirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.largeTitle)
                .foregroundColor(Color.gold400)
                .symbolEffect(.bounce, value: isRedeeming)
            Text("Použiť kľúč od tanečníka?")
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundColor(.white)
            Text("Uvidíš jeho zostavu a môžeš k nej písať poznámky. Majiteľ kľúča uvidí tvoje meno.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            PrimarySheetButton(title: "Použiť kľúč", isLoading: false, isEnabled: true, action: redeem)
                .accessibilityIdentifier("guestKey.redeem")
                .padding(.top, 8)
        }
        .padding(.horizontal, 32)
    }

    private func redeem() {
        isRedeeming = true
        Task {
            defer { isRedeeming = false }
            do {
                access = try await GuestCoachService.shared.redeem(token)
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

/// The guest's view of a lent routine: figures in order, with the guest's own notes under each.
struct GuestRoutineView: View {
    let access: GuestAccess

    @State private var figures: [GuestFigure] = []
    @State private var notes: [GuestNote] = []
    @State private var drafts: [UUID: String] = [:]
    @State private var savingNode: UUID?
    @State private var errorText: String?
    @State private var isLoading = true
    @State private var successTick = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(access.routineName)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                    Text("\(access.danceName) · od \(access.ownerName.isEmpty ? "tanečníka" : access.ownerName) · do \(access.expiresAt.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "sk"))))")
                        .font(.footnote)
                        .foregroundColor(Color.textSecondary)
                    Text("Tvoje poznámky uvidí len tanečník. Ostanú mu aj po skončení kľúča.")
                        .font(.caption)
                        .foregroundColor(Color.gold300)
                }

                if isLoading {
                    ProgressView().tint(Color.gold400).frame(maxWidth: .infinity)
                } else if figures.isEmpty {
                    Text("Zostava je zatiaľ prázdna alebo kľúč už neplatí.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.65))
                }

                ForEach(figures) { figure in
                    figureCard(figure)
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Zostava na seminári")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Nepodarilo sa", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText ?? "")
        }
        .sensoryFeedback(.success, trigger: successTick)
        .task { await load() }
        .refreshable { await load() }
    }

    private func figureCard(_ figure: GuestFigure) -> some View {
        let mine = notes.filter { $0.nodeId == figure.nodeId }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(figure.orderIndex + 1). \(figure.figureName)")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Spacer()
                if !figure.rhythm.isEmpty {
                    Text(figure.rhythm)
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color.gold300)
                }
            }
            ForEach(mine) { note in
                Text(note.body)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.85))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gold500.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("", text: Binding(
                    get: { drafts[figure.nodeId] ?? "" },
                    set: { drafts[figure.nodeId] = $0 }
                ), prompt: Text("Poznámka k figúre").foregroundColor(.white.opacity(0.4)), axis: .vertical)
                    .lineLimit(1...4)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Button {
                    save(figure)
                } label: {
                    Image(systemName: savingNode == figure.nodeId ? "hourglass" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color.gold400)
                }
                .disabled((drafts[figure.nodeId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || savingNode != nil)
                .accessibilityLabel("Uložiť poznámku")
            }
        }
        .padding(14)
        .homeCard(cornerRadius: 18)
    }

    private func load() async {
        defer { isLoading = false }
        do {
            async let loadedFigures = GuestCoachService.shared.figures(of: access.routineId)
            async let loadedNotes = GuestCoachService.shared.myNotes(in: access.routineId)
            figures = try await loadedFigures
            notes = try await loadedNotes
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func save(_ figure: GuestFigure) {
        let text = (drafts[figure.nodeId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        savingNode = figure.nodeId
        Task {
            defer { savingNode = nil }
            do {
                try await GuestCoachService.shared.addNote(text, keyId: access.keyId, routineId: access.routineId, nodeId: figure.nodeId)
                drafts[figure.nodeId] = ""
                notes = try await GuestCoachService.shared.myNotes(in: access.routineId)
                successTick += 1
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}

// MARK: - Guest: routines lent to me (Nástroje)
struct GuestRoutinesListView: View {
    @State private var keys: [GuestCoachKey] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            EllegancePageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Zostavy, ktoré ti tanečníci požičali kľúčom. Po skončení kľúča zmiznú, tvoje poznámky im ostanú.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                    if isLoading {
                        ProgressView().tint(Color.gold400).frame(maxWidth: .infinity)
                    } else if keys.isEmpty {
                        Text("Zatiaľ nič. Naskenuj kľúč tanečníka cez Domov → logo → Skenovať QR.")
                            .font(.footnote)
                            .foregroundColor(Color.textSecondary)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .homeCard(cornerRadius: 18)
                    }
                    ForEach(keys) { key in
                        NavigationLink {
                            GuestRoutineView(access: GuestAccess(
                                keyId: key.id,
                                routineId: key.routineId,
                                routineName: key.routine?.name ?? "Zostava",
                                danceName: key.routine?.danceName ?? "",
                                ownerName: "",
                                expiresAt: key.expiresAt
                            ))
                            .background(EllegancePageBackground())
                        } label: {
                            HomeRow(
                                icon: "key.fill",
                                title: key.routine?.name ?? "Zostava",
                                subtitle: "\(key.routine?.danceName ?? "") · do \(key.expiresAt.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "sk"))))"
                            )
                            .homeCard(cornerRadius: 18)
                        }
                        .buttonStyle(.pressable(scale: 0.98))
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Požičané zostavy")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            keys = (try? await GuestCoachService.shared.myAccess()) ?? []
            isLoading = false
        }
    }
}

// MARK: - Dancer: guest notes on a figure
/// Shown on the figure card when a guest coach left notes.
struct GuestNotesOnFigure: View {
    let nodeId: UUID

    @State private var notes: [GuestNote] = []

    var body: some View {
        Group {
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HomeSectionHeader(title: "HOSŤUJÚCI TRÉNER", systemImage: "key.fill", count: notes.count)
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.body)
                                .font(.subheadline)
                                .foregroundColor(.white)
                            Text([note.key?.guestName, note.createdAt.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "sk")))]
                                .compactMap { $0 }.joined(separator: " · "))
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .homeCard(cornerRadius: 14)
                    }
                }
            }
        }
        .task(id: nodeId) {
            notes = (try? await GuestCoachService.shared.notes(forNode: nodeId)) ?? []
        }
    }
}
