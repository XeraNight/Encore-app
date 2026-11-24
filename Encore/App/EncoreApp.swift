import SwiftUI
import OSLog
import SwiftData
import GoogleSignIn
import UIKit

// MARK: - App Delegate for Orientation Control (Portrait lock with Canvas exception)
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // The notification delegate must be in place before launch ends, or the tap that opened the app is lost.
        _ = NotificationManager.shared
        return true
    }
}

@main
struct EncoreApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    /// Each account's own data on this iPhone; switching accounts switches the database.
    @StateObject private var accounts = AccountStore.shared

    init() {
        MainActor.assumeIsolated {
            // Changes made offline go up whenever the network or the app comes back.
            PendingSyncRunner.shared.start()
        }
        Task.detached(priority: .utility) { MediaStorageManager.removeOldTemporaryFiles() }
    }

    var body: some Scene {
        WindowGroup {
            RootAppView()
                .modelContainer(accounts.container)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // 1. Google Sign-In redirect
                    if GIDSignIn.sharedInstance.handle(url) { return }
                    // 2. Supabase auth callbacks (e-mail confirm, OAuth, password recovery).
                    //    These carry a `code` query item that FriendManager would misread as an invite code.
                    if url.scheme == "encore", url.host == "auth-callback" {
                        Task { await AuthManager.shared.handleDeepLink(url) }
                        return
                    }
                    // 3. Lock Screen / Control Center buttons (encore://quick/…)
                    if let action = QuickAction(url: url) {
                        QuickActionRouter.shared.pending = action
                        return
                    }
                    // 4. The training card on the Lock Screen (encore://plan?…) opens that training's reflection.
                    if let request = PlannerOpenRequest(url: url) {
                        PlannerRouter.shared.pending = request
                        return
                    }
                    // 5. Guest coach key (encore://guest?k=…)
                    if AppFeatures.coachTools, let token = GuestCoachLink.token(from: url.absoluteString) {
                        GuestCoachService.shared.pendingToken = token
                        return
                    }
                    // 6. Friend invites / profile links
                    Task { _ = FriendManager.shared.handleIncomingURL(url) }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    guard let url = userActivity.webpageURL else { return }
                    // Lock Screen / Control Center buttons open https://www.encore-sk.com/quick/…
                    if let action = QuickAction(url: url) {
                        QuickActionRouter.shared.pending = action
                        return
                    }
                    Task {
                        _ = FriendManager.shared.handleIncomingURL(url)
                    }
                }
        }
    }

    // MARK: - Background seed using a dedicated ModelActor context
    // Runs entirely off the main thread — zero impact on first-frame render.
    static func seedIfNeeded(container: ModelContainer) async {
        // Create a background context (ModelActor) for safe off-thread access
        let bgContext = ModelContext(container)

        var fetch = FetchDescriptor<Dance>()
        fetch.fetchLimit = 1

        do {
            let existing = try bgContext.fetch(fetch)
            guard existing.isEmpty else {   // already seeded
                updateSeededTempoTexts(in: bgContext)
                return
            }
            populateDefaultData(context: bgContext)
        } catch {
            Logger.general.error("Seed check failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// The tempo texts the library was seeded with before it spoke in takty ("28–30 MPM (84–90 BPM)", Samba with the range
    /// of another organisation). A dance whose text is still exactly that gets the one SZTŠ prescribes; a text the
    /// dancer edited stays.
    private static let formerSeedTempo: [String: String] = [
        "Waltz": "28–30 MPM (84–90 BPM)", "Tango": "31–33 MPM (124–132 BPM)", "Viennese Waltz": "58–60 MPM (174–180 BPM)",
        "Slowfoxtrot": "28–30 MPM (112–120 BPM)", "Quickstep": "50–52 MPM (200–208 BPM)", "Samba": "48–50 MPM (96–100 BPM)",
        "Cha-Cha-Cha": "30–32 MPM (120–128 BPM)", "Rumba": "25–27 MPM (100–108 BPM)", "Paso Doble": "60–62 MPM (120–124 BPM)",
        "Jive": "42–44 MPM (168–176 BPM)",
    ]

    static func updateSeededTempoTexts(in context: ModelContext) {
        guard let dances = try? context.fetch(FetchDescriptor<Dance>()) else { return }
        var changed = false
        for dance in dances {
            guard let former = formerSeedTempo[dance.name], dance.tempo == former,
                  let text = DanceMetronomePreset.forLibraryDance(dance.name)?.tempoText else { continue }
            dance.tempo = text
            changed = true
        }
        if changed { context.saveOrLog() }
    }

    private static func populateDefaultData(context: ModelContext) {
        // Standard Dances
        let dances: [(String, String, String)] = [
            ("Waltz",          "Standard", "Sústreď sa na Rise & Fall. Klesanie prebieha na konci doby 3, zdvih začína na 1. Dôležitý je aj Sway."),
            ("Tango",          "Standard", "Tango nemá Rise & Fall. Pohyb je ostrý, staccato. Držanie je kompaktnejšie a kolená sú neustále mierne pokrčené."),
            ("Viennese Waltz", "Standard", "Pri tej rýchlosti je kľúčová rotácia a plynulosť. Sústreď sa na čisté otáčky a prechodové kroky."),
            ("Slowfoxtrot",    "Standard", "Najťažší tanec na techniku. Vyžaduje lineárny pohyb a extrémne tiché dopady. Rytmizácia je väčšinou Slow, Quick, Quick."),
            ("Quickstep",      "Standard", "Vyhýbaj sa skákaniu. Pruženie vychádza z členkov a kolien, zatiaľ čo vrchná časť tela zostáva pokojná."),
            ("Samba",          "Latin",    "Základom je Samba Bounce. Nejde o skákanie, ale o prácu s panvou v rytme 1 a 2."),
            ("Cha-Cha-Cha",    "Latin",    "Akcent je na dobu 1. Kroky musia byť ostré, nohy prepnuté a váha musí byť vpredu na bruškách chodidiel."),
            ("Rumba",          "Latin",    "Tanec lásky. Veď pohyb z centra tela a doťahuj každý krok. Jednotka sa netancuje."),
            ("Paso Doble",     "Latin",    "Muž je toreador, žena muleta. Vysoké držanie, podsadená panva a silný očný kontakt."),
            ("Jive",           "Latin",    "Vyžaduje kondíciu. Odraz z brušiek a swingový charakter. Jive nie je len o nohách.")
        ]
        // The tempo of each dance is the one SZTŠ prescribes, from the metronome's table.
        for (name, cat, info) in dances {
            context.insert(Dance(name: name, category: cat, tempo: DanceMetronomePreset.forLibraryDance(name)?.tempoText ?? "", info: info))
        }

        FigureLibraryItem.seedDefaultFigures(in: context)

        try? context.save()
    }
}

// MARK: - Root App Authentication Gate & Precautions Guard
struct RootAppView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var remoteConfig = RemoteConfigManager.shared
    @ObservedObject private var friendManager = FriendManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var profileStore = UserProfileStore.shared
    @ObservedObject private var accounts = AccountStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var dismissMaintenanceOffline = false
    @State private var isSplashActive = true
    /// Set when Encore went to the background, consumed on the next "active" (see the scenePhase handler).
    @State private var leftForBackground = false

    var body: some View {
        ZStack {
            if isSplashActive {
                AppSplashView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        isSplashActive = false
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            } else if authManager.isAuthenticated {
                // Another account's data: every screen starts again on it.
                MainTabView()
                    .id(accounts.accountId)
                    .transition(.opacity)
            } else {
                AuthSheetView(isSheet: false)
                    .transition(.opacity)
            }
            
            // Emergency Precautions & Fallback Overlays
            if remoteConfig.needsForceUpdate {
                ForceUpdateView(appStoreURL: remoteConfig.appStoreURL)
                    .transition(.opacity)
                    .zIndex(200)
            } else if remoteConfig.isMaintenanceMode && !dismissMaintenanceOffline {
                MaintenanceNoticeView(message: remoteConfig.maintenanceMessage) {
                    dismissMaintenanceOffline = true
                }
                .transition(.opacity)
                .zIndex(190)
            }
            
            // Account Banned / Suspended Interceptor
            if subscriptionManager.isAccountBanned {
                AccountBannedNoticeView(reason: subscriptionManager.banReason) {
                    Task {
                        await authManager.signOut(forgetDevice: true)
                        subscriptionManager.isAccountBanned = false
                    }
                }
                .transition(.opacity)
                .zIndex(250)
            }
        }
        .animation(.easeInOut(duration: 0.32), value: isSplashActive)
        .animation(.easeInOut(duration: 0.32), value: subscriptionManager.isAccountBanned)
        .animation(.easeInOut(duration: 0.32), value: authManager.isAuthenticated)
        .animation(.easeInOut(duration: 0.28), value: remoteConfig.needsForceUpdate)
        .animation(.easeInOut(duration: 0.28), value: remoteConfig.isMaintenanceMode)
        .sheet(isPresented: $friendManager.showInviteSheet) {
            if let invite = friendManager.incomingInvite {
                FriendInviteSheetView(invite: invite) {
                    friendManager.showInviteSheet = false
                    friendManager.incomingInvite = nil
                }
            }
        }
        // A dead, revoked or unknown code says so (inside the invite sheet the sheet itself shows the reason).
        .alert("QR kód sa nedá použiť", isPresented: Binding(
            get: { friendManager.inviteErrorMessage != nil && !friendManager.showInviteSheet },
            set: { if !$0 { friendManager.inviteErrorMessage = nil } }
        )) {
            Button("Rozumiem", role: .cancel) {}
        } message: {
            Text(friendManager.inviteErrorMessage ?? "")
        }
        .sheet(isPresented: $friendManager.showDeferredInvitePrompt) {
            DeferredInvitePasteSheet()
        }
        .sheet(isPresented: $authManager.showPasswordRecoverySheet) {
            PasswordUpdateSheet(mode: .recovery)
        }
        // Not over the Face ID lock or the login screen.
        .sheet(isPresented: Binding(
            get: { profileStore.asksBirthYear && authManager.isAuthenticated && !authManager.isAppLocked },
            set: { profileStore.asksBirthYear = $0 }
        )) {
            BirthYearSheet()
        }
        // The Face ID lock lives in its own window above everything, from the end of the splash on.
        .onChange(of: isSplashActive) { _, splash in
            guard !splash, let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
            AppLockWindow.shared.start(in: scene)
            PrivacyCoverWindow.shared.prepare()
        }
        .task {
            await PlannerNotifications.rescheduleFromStore()
            await remoteConfig.syncConfig()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Face ID lock on: while Encore is not in front, the app switcher shows the logo and not the screen.
            if PrivacyCoverWindow.shouldCover(isActive: newPhase == .active, lockIsOn: authManager.isBiometricsEnabled,
                                              isSignedIn: authManager.isAuthenticated, isLocked: authManager.isAppLocked) {
                PrivacyCoverWindow.shared.show()
            } else if newPhase == .active {
                PrivacyCoverWindow.shared.hide()
            }
            if newPhase == .background {
                leftForBackground = true
                authManager.appDidEnterBackground()
                // What was written just now goes up while iOS still gives the app a moment.
                PendingSyncRunner.shared.run()
            }
            // SwiftUI reports a return as background, inactive, active, so the old phase is never "background" here:
            // everything keys off "active", and the work that only a real trip needs checks `leftForBackground`.
            if newPhase == .active {
                authManager.appDidBecomeActive()
                if leftForBackground {
                    leftForBackground = false
                    authManager.refreshBiometryType()
                    Task { await SubscriptionManager.shared.refreshEntitlementsAfterBackground() }
                }
                // Device woke up from lock screen or returned from background!
                UserProfileStore.shared.refreshForActiveUser()
                friendManager.checkPendingInviteAfterLogin()
                friendManager.checkPasteboardForDeferredInvite()
                PendingSyncRunner.shared.run()
                Task {
                    await PlannerNotifications.rescheduleFromStore()
                    await authManager.checkCurrentSession()
                    await remoteConfig.syncConfig()
                }
            }
        }
    }
}
