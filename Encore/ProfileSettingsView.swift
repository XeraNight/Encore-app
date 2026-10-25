import SwiftUI
import SwiftData

// MARK: - Settings (opened from Profile)
/// Everything about the app and the account in one place: account, sign-in, notifications, playback,
/// data, help, the owner console and account deletion.
struct ProfileSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var profileStore = UserProfileStore.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared

    @State private var showChangePassword = false
    @State private var confirmSignOut = false
    @State private var confirmDeleteAccount = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?
    @State private var showLegal = false
    @State private var showOwnerConsole = false
    @State private var confirmResetLibrary = false
    @State private var confirmClearVideos = false
    @State private var exportFile: ExportFile?
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var storageBytes: Int64?
    @State private var changeCount = 0

    var body: some View {
        ZStack {
            EllegancePageBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    accountSection
                    signInSection
                    notificationsSection
                    playbackSection
                    dataSection
                    helpSection
                    if subscriptionManager.isAppOwner { ownerSection }
                    deleteSection

                    Text(appVersion)
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("Nastavenia")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshStorageUsage() }
        .sheet(isPresented: $showChangePassword) { PasswordUpdateSheet(mode: .change) }
        .sheet(isPresented: $showLegal) { LegalComplianceView() }
        .sheet(isPresented: $showOwnerConsole) { OwnerAdminConsoleView() }
        .sheet(item: $exportFile) { ActivityShareSheet(items: [$0.url]) }
        .confirmationDialog("Odhlásiť sa z tohto iPhonu?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Odhlásiť sa", role: .destructive) {
                Task { await authManager.signOut() }
            }
        } message: {
            Text("Tvoje zostavy ostanú v cloude. Na ostatných zariadeniach ostaneš prihlásený.")
        }
        .confirmationDialog("Obnoviť predvolenú knižnicu figúr?", isPresented: $confirmResetLibrary, titleVisibility: .visible) {
            Button("Obnoviť knižnicu", role: .destructive, action: resetFigureLibrary)
        } message: {
            Text("Tvoje vlastné figúry ostanú. Predvolené figúry sa načítajú znova.")
        }
        .confirmationDialog("Vymazať videá z Encore?", isPresented: $confirmClearVideos, titleVisibility: .visible) {
            Button("Vymazať videá", role: .destructive, action: clearVideos)
        } message: {
            Text("Videá zostáv, figúr a tancov uložené v Encore sa vymažú z tohto iPhonu. Videá vo Fotkách a v Denníku ostanú.")
        }
        .confirmationDialog("Natrvalo zmazať účet?", isPresented: $confirmDeleteAccount, titleVisibility: .visible) {
            Button("Zmazať účet", role: .destructive) { Task { await deleteAccount() } }
        } message: {
            Text("Zmaže sa profil, zostavy, poznámky, videá v cloude aj prihlasovací účet. Nedá sa to vrátiť. Predplatné v App Store zrušíš v Nastaveniach iPhonu (Apple ID → Predplatné).")
        }
        .alert("Účet sa nepodarilo zmazať", isPresented: Binding(get: { deleteAccountError != nil }, set: { if !$0 { deleteAccountError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteAccountError ?? "")
        }
        .alert("Dáta sa nepodarilo stiahnuť", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .sensoryFeedback(.selection, trigger: changeCount)
        .environment(\.locale, Locale(identifier: "sk"))
    }

    // MARK: Account
    private var accountSection: some View {
        HomeRowGroup(title: "ÚČET") {
            HomeRow(icon: "envelope.fill", title: "E-mail", subtitle: authManager.userEmail, showsChevron: false)

            if AppFeatures.coachTools {
                HomeRowDivider()

                HStack(spacing: 0) {
                    HomeRow(
                        icon: profileStore.isCoach ? "person.badge.shield.checkmark.fill" : "figure.dance",
                        title: "Moja rola",
                        subtitle: "Tréneri vidia Trénerské štúdio. Práva k žiakom dáva až prijaté prepojenie.",
                        showsChevron: false
                    )
                    Picker("Moja rola", selection: Binding(
                        get: { profileStore.danceRole },
                        set: { profileStore.setDanceRole($0); changeCount += 1 }
                    )) {
                        Text("Tanečník").tag("dancer")
                        Text("Tréner").tag("coach")
                    }
                    .pickerStyle(.menu)
                    .tint(Color.gold400)
                    .labelsHidden()
                    .padding(.trailing, 8)
                }
            }

            if authManager.canChangePassword {
                HomeRowDivider()
                Button { showChangePassword = true } label: {
                    HomeRow(icon: "lock.rotation", title: "Zmeniť heslo")
                }
                .buttonStyle(.pressable(scale: 0.98))
            }

            HomeRowDivider()

            Button { confirmSignOut = true } label: {
                HomeRow(icon: "rectangle.portrait.and.arrow.right", title: "Odhlásiť sa", isDestructive: true, showsChevron: false)
            }
            .buttonStyle(.pressable(scale: 0.98))
        }
    }

    // MARK: Sign-in
    private var signInSection: some View {
        HomeRowGroup(title: "PRIHLÁSENIE") {
            toggleRow(
                icon: authManager.biometrySystemImage,
                title: "Prihlásenie cez \(authManager.biometryName)",
                subtitle: "Ostaneš prihlásený a pri otvorení Encore sa overíš tvárou. Zapnutie potvrdíš \(authManager.biometryName).",
                isOn: Binding(
                    get: { authManager.isBiometricsEnabled },
                    set: { newValue in
                        Task {
                            await authManager.setBiometricLogin(newValue)
                            changeCount += 1
                        }
                    }
                )
            )
        }
    }

    // MARK: Notifications
    private var notificationsSection: some View {
        HomeRowGroup(title: "UPOZORNENIA") {
            toggleRow(
                icon: "bell.badge.fill",
                title: "Upozornenia na tréningy",
                subtitle: "Hodinu pred tréningom, po tréningu a pred súťažou.",
                isOn: Binding(
                    get: { notificationManager.notificationsEnabled },
                    set: { isOn in
                        notificationManager.notificationsEnabled = isOn
                        changeCount += 1
                        if isOn && !notificationManager.isAuthorized {
                            Task { _ = await notificationManager.requestAuthorization() }
                        }
                    }
                )
            )
        }
    }

    // MARK: Playback
    private var playbackSection: some View {
        HomeRowGroup(title: "PREHRÁVANIE") {
            HStack(spacing: 0) {
                HomeRow(icon: "play.circle.fill", title: "Rýchlosť videí v knižnici", showsChevron: false)
                Picker("Rýchlosť videí", selection: Binding(
                    get: { profileStore.currentPlaybackRate },
                    set: { profileStore.setPlaybackRate($0); changeCount += 1 }
                )) {
                    Text("0,5×").tag(0.5)
                    Text("0,75×").tag(0.75)
                    Text("1×").tag(1.0)
                    Text("1,5×").tag(1.5)
                }
                .pickerStyle(.menu)
                .tint(Color.gold400)
                .labelsHidden()
                .padding(.trailing, 8)
            }
        }
    }

    // MARK: Data
    private var dataSection: some View {
        HomeRowGroup(title: "DÁTA") {
            HomeRow(
                icon: "internaldrive.fill",
                title: "Encore v tomto iPhone",
                subtitle: "Videá, fotky a hlasovky uložené v appke (bez Fotiek)",
                detail: storageBytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "…",
                showsChevron: false
            )
            HomeRowDivider()
            Button { confirmResetLibrary = true } label: {
                HomeRow(icon: "arrow.counterclockwise.circle.fill", title: "Obnoviť predvolenú knižnicu figúr")
            }
            .buttonStyle(.pressable(scale: 0.98))
            HomeRowDivider()
            Button { confirmClearVideos = true } label: {
                HomeRow(icon: "video.slash.fill", title: "Vymazať videá z Encore", isDestructive: true, showsChevron: false)
            }
            .buttonStyle(.pressable(scale: 0.98))
        }
    }

    // MARK: Help
    private var helpSection: some View {
        HomeRowGroup(title: "POMOC A PRÁVNE") {
            NavigationLink { VideoGuideView() } label: {
                HomeRow(icon: "play.rectangle.on.rectangle.fill", title: "Ako fungujú videá", subtitle: AppFeatures.sharedVideos
                         ? "Fotky, zdieľanie s partnerom a miesto v pláne."
                         : "Kde sú tvoje videá a ako ich poslať partnerovi.")
            }
            .buttonStyle(.pressable(scale: 0.98))
            HomeRowDivider()
            Button(action: openFeedbackEmail) {
                HomeRow(icon: "envelope.badge.fill", title: "Spätná väzba a nahlásenie chyby")
            }
            .buttonStyle(.pressable(scale: 0.98))
            HomeRowDivider()
            Button { showLegal = true } label: {
                HomeRow(icon: "hand.raised.fill", title: "Ochrana súkromia a podmienky")
            }
            .buttonStyle(.pressable(scale: 0.98))
            HomeRowDivider()
            // GDPR art. 15 and 20: the user can download their data at any time.
            Button { Task { await exportMyData() } } label: {
                HomeRow(
                    icon: "arrow.down.doc.fill",
                    title: isExporting ? "Pripravujem súbor…" : "Stiahnuť moje dáta",
                    subtitle: "Všetko, čo o tebe Encore uchováva na serveri a v tomto iPhone, v jednom súbore."
                )
            }
            .buttonStyle(.pressable(scale: 0.98))
            .disabled(isExporting)
        }
    }

    // MARK: Owner
    private var ownerSection: some View {
        HomeRowGroup(title: "MAJITEĽ") {
            Button { showOwnerConsole = true } label: {
                HomeRow(icon: "crown.fill", title: "Majiteľská konzola", subtitle: "Plány, granty a blokovanie účtov.")
            }
            .buttonStyle(.pressable(scale: 0.98))
        }
        .transition(.opacity)
    }

    // MARK: Delete account
    private var deleteSection: some View {
        HomeRowGroup(title: "ZMAZANIE ÚČTU") {
            Button { confirmDeleteAccount = true } label: {
                HomeRow(
                    icon: "person.crop.circle.badge.xmark",
                    title: isDeletingAccount ? "Mažem účet…" : "Zmazať účet a osobné dáta",
                    subtitle: "Pred zmazaním potvrdíš svoju totožnosť cez \(authManager.biometryName) alebo kód.",
                    isDestructive: true,
                    showsChevron: false
                )
            }
            .buttonStyle(.pressable(scale: 0.98))
            .disabled(isDeletingAccount)
        }
    }

    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 0) {
            HomeRow(icon: icon, title: title, subtitle: subtitle, showsChevron: false)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(Color.gold500)
                .padding(.trailing, 14)
        }
    }

    // MARK: Actions
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Encore \(version) (\(build))"
    }

    /// A stolen, unlocked iPhone must not be enough: the owner confirms with Face ID or the passcode.
    private func deleteAccount() async {
        guard await authManager.confirmDeviceOwner(reason: "Potvrď zmazanie účtu Encore") else { return }
        isDeletingAccount = true
        deleteAccountError = await authManager.deleteAccount()
        isDeletingAccount = false
    }

    /// Everything Encore keeps in its own folder, read off the main thread.
    private func refreshStorageUsage() async {
        let bytes = await Task.detached(priority: .utility) { MediaStorageManager.documentsSize() }.value
        withAnimation(.easeOut(duration: 0.2)) { storageBytes = bytes }
    }

    private func resetFigureLibrary() {
        let descriptor = FetchDescriptor<FigureLibraryItem>(predicate: #Predicate { !$0.isCustom })
        for figure in (try? modelContext.fetch(descriptor)) ?? [] {
            MediaStorageManager.removeFile(named: figure.imagePath)
            MediaStorageManager.removeFile(named: figure.videoPath)
            modelContext.delete(figure)
        }
        FigureLibraryItem.seedDefaultFigures(in: modelContext)
        changeCount += 1
    }

    /// Frees space: the figure, library and dance videos kept in Encore. A file Denník still shows stays, and a
    /// Fotky video is only unlinked (it stays in Fotky).
    private func clearVideos() {
        let nodes = (try? modelContext.fetch(FetchDescriptor<CanvasNode>(predicate: #Predicate { $0.videoPath != nil }))) ?? []
        let figures = (try? modelContext.fetch(FetchDescriptor<FigureLibraryItem>(predicate: #Predicate { $0.videoPath != nil }))) ?? []
        let dances = (try? modelContext.fetch(FetchDescriptor<Dance>(predicate: #Predicate { $0.videoPath != nil }))) ?? []
        let paths = nodes.compactMap(\.videoPath) + figures.compactMap(\.videoPath) + dances.compactMap(\.videoPath)
        nodes.forEach { $0.videoPath = nil }
        figures.forEach { $0.videoPath = nil }
        dances.forEach { $0.videoPath = nil }
        try? modelContext.save()
        Set(paths).forEach { MediaStorageManager.removeVideoIfUnused($0, in: modelContext) }
        changeCount += 1
        Task { await refreshStorageUsage() }
    }

    private func openFeedbackEmail() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let ios = UIDevice.current.systemVersion
        let url = AppContact.mailURL(
            subject: "Encore – spätná väzba (\(version) [\(build)] / iOS \(ios))",
            body: "\n\n---\nEncore \(version) (\(build)), iOS \(ios)"
        )
        if let url { UIApplication.shared.open(url) }
    }

    /// Server data plus this iPhone's data in one JSON file, then the share sheet (save to Files, AirDrop, mail).
    private func exportMyData() async {
        isExporting = true
        defer { isExporting = false }
        do {
            exportFile = ExportFile(url: try await MyDataExport.makeFile(context: modelContext))
            changeCount += 1
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private struct ExportFile: Identifiable {
    let url: URL
    var id: URL { url }
}

// MARK: - Share sheet
/// System share sheet for files (export).
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
