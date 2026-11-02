import SwiftUI
import SwiftData

// MARK: - Main Tab View (native Liquid Glass TabView)
struct MainTabView: View {

    // Tab index: 0 = Domov, 1 = Canvas, 2 = Kalendár, 3 = Profil
    @State private var selectedTab: Int = 0
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var plannerRouter = PlannerRouter.shared
    @ObservedObject private var quickActions = QuickActionRouter.shared
    @State private var ksisBrowser: KSISBrowserTarget?
    @State private var showResults = false
    @State private var offerBiometricLogin = false

    var body: some View {
        ZStack {
            // Root velvet stage background covering the whole screen without black bars
            EllegancePageBackground()

            TabView(selection: $selectedTab) {
                Tab("Domov", systemImage: "house.fill", value: 0) {
                    ContentView()
                }

                Tab("Zostavy", systemImage: "square.grid.2x2.fill", value: 1) {
                    CanvasRoutinesHubView()
                }

                Tab("Kalendár", systemImage: "calendar", value: 2) {
                    DancePlannerView()
                }

                Tab("Profil", systemImage: "person.crop.circle.fill", value: 3) {
                    ProfileView()
                }
            }
            .tint(Color.gold400)
            .figureMiniPlayer()
        }
        // Signed out: a figure video with sound must not play on.
        .onDisappear { FigureVideoPlayback.shared.stop() }
        // A tapped "Tréning skončil" notification: the Kalendár tab opens the reflection.
        .onChange(of: plannerRouter.pending, initial: true) { _, request in
            if request != nil { selectedTab = 2 }
        }
        // A Lock Screen button: camera, voice and text open on Home (it handles them), KSIS opens here.
        .onChange(of: quickActions.pending, initial: true) { _, action in
            guard let action else { return }
            switch action {
            case .ksis:
                quickActions.pending = nil
                if let url = QuickAction.ksisCalendarURL { ksisBrowser = KSISBrowserTarget(url: url) }
            case .results:
                quickActions.pending = nil
                showResults = true
            case .video, .voice, .text:
                selectedTab = 0
            }
        }
        .fullScreenCover(item: $ksisBrowser) { KSISBrowserView(startURL: $0.url) }
        .sheet(isPresented: $showResults) { NavigationStack { CompetitionTrackerView() } }
        .task {
            // Once per account, a moment after the first sign-in on this iPhone.
            try? await Task.sleep(for: .seconds(1.5))
            offerBiometricLogin = authManager.shouldOfferBiometricLogin
        }
        .alert("Prihlasovať sa cez \(authManager.biometryName)?", isPresented: $offerBiometricLogin) {
            Button("Zapnúť") {
                authManager.markBiometricOfferShown()
                Task { await authManager.setBiometricLogin(true) }
            }
            Button("Teraz nie", role: .cancel) { authManager.markBiometricOfferShown() }
        } message: {
            Text("Ostaneš prihlásený a pri otvorení Encore sa overíš tvárou. Zmeniť to môžeš v Profile → Nastavenia.")
        }
        .onAppear {
            // Transparent Navigation Bar
            let navAppearance = UINavigationBarAppearance()
            navAppearance.configureWithTransparentBackground()
            navAppearance.backgroundColor = .clear
            navAppearance.shadowColor = .clear
            // Titles in SF Rounded like the Home headers (§1A), not serif.
            func rounded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
                let base = UIFont.systemFont(ofSize: size, weight: weight)
                return base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
            }
            navAppearance.titleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: rounded(17, .bold)
            ]
            navAppearance.largeTitleTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: rounded(32, .heavy)
            ]
            UINavigationBar.appearance().standardAppearance = navAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
            UINavigationBar.appearance().compactAppearance = navAppearance
            UINavigationBar.appearance().tintColor = UIColor(Color.gold500)
            UITextView.appearance().backgroundColor = .clear
        }
    }
}

// MARK: - Xcode Canvas Preview (Safe Static Container for Instant Live Preview)
#Preview("MainTabView - App Workspace & Dock") {
    let schema = Schema([
        Dance.self,
        FigureLibraryItem.self,
        Routine.self,
        CanvasNode.self,
        InstantNote.self,
        VideoMediaEntry.self,
        TrainingCadence.self,
        TrainingLogEntry.self,
        PlannedCompetition.self,
        PlannedSession.self,
        LessonPriority.self
    ])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    
    return MainTabView()
        .modelContainer(container)
        .preferredColorScheme(.dark)
}



