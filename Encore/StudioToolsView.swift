import SwiftUI

// MARK: - Nástroje (opened from Profile)
/// Practice tools for every dancer, plus the student roster for coaches. Home style (BRAND_GUIDELINES §1A).
struct StudioToolsView: View {
    @ObservedObject private var profileStore = UserProfileStore.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var showCoachRoster = false
    @State private var showMusicSpeedTrainer = false
    @State private var showSeminarSplitter = false
    @State private var showDanceMirror = false
    @State private var showDanceMetronome = false
    @State private var showPaywall = false

    /// Strih lekcie is part of Plus (docs/V1_PAYWALL_FEATURES_PLAN.md).
    private var hasPlus: Bool { subscriptionManager.currentTier >= .plus }

    private var showsCoachTools: Bool { AppFeatures.coachTools && (profileStore.isCoach || subscriptionManager.isAppOwner) }

    var body: some View {
        ZStack {
            EllegancePageBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    if showsCoachTools {
                        HomeRowGroup(title: "TRÉNER") {
                            toolRow(icon: "person.3.sequence.fill", title: "Moji zverenci",
                                    subtitle: "Zostavy žiakov, poznámky trénera a priradenie figúr") { showCoachRoster = true }
                        }
                        .transition(.opacity)
                    }

                    HomeRowGroup(title: "TRÉNING") {
                        toolRow(icon: "person.crop.rectangle.fill", title: "Zrkadlo",
                                subtitle: "Predná kamera na celú obrazovku, aj s prisvietením") { showDanceMirror = true }
                        HomeRowDivider()
                        toolRow(icon: "metronome.fill", title: "Metronóm a tempo",
                                subtitle: "Klik pre všetkých 10 tancov, hrá aj popri hudbe") { showDanceMetronome = true }
                        HomeRowDivider()
                        toolRow(icon: "music.note", title: "Hudba pomalšie a rýchlejšie",
                                subtitle: "Tvoja skladba od 70 do 130 % bez zmeny tóniny") { showMusicSpeedTrainer = true }
                        HomeRowDivider()
                        toolRow(icon: "scissors", title: "Strih lekcie na figúry",
                                subtitle: "Dlhé video z lekcie rozdelíš na jednotlivé figúry",
                                badge: hasPlus ? nil : "PLUS") {
                            if hasPlus { showSeminarSplitter = true } else { showPaywall = true }
                        }
                    }

                    if AppFeatures.coachTools {
                        HomeRowGroup(title: "SEMINÁR") {
                            NavigationLink {
                                GuestRoutinesListView()
                            } label: {
                                HomeRow(icon: "key.fill", title: "Požičané zostavy",
                                        subtitle: "Zostavy, ktoré ti tanečníci požičali kľúčom")
                            }
                            .buttonStyle(.pressable(scale: 0.98))
                        }
                    }

                    HomeRowGroup(title: "SÁLA") {
                        HStack(spacing: 0) {
                            HomeRow(
                                icon: "tv.fill",
                                title: "Obrazovka v sále",
                                subtitle: "Videá pošleš cez AirPlay. Celý parket ukážeš cez Zrkadlenie obrazovky v Ovládacom centre.",
                                showsChevron: false
                            )
                            AirPlayRoutePickerRepresentable(tintColor: UIColor(Color.gold400))
                                .frame(width: 44, height: 44)
                                .padding(.trailing, 10)
                                .accessibilityLabel("Vybrať obrazovku")
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("Nástroje")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showsCoachTools)
        .sheet(isPresented: $showMusicSpeedTrainer) { MusicSpeedTrainerSheet() }
        .sheet(isPresented: $showSeminarSplitter) { SeminarSplitterView() }
        .sheet(isPresented: $showPaywall) { SubscriptionPaywallView(initialTier: .plus) }
        .sheet(isPresented: $showCoachRoster) {
            NavigationStack { StudioCoachRosterView() }
        }
        .sheet(isPresented: $showDanceMetronome) { DanceMetronomeView() }
        .fullScreenCover(isPresented: $showDanceMirror) {
            DanceMirrorView()
                .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NÁSTROJE")
                .font(.system(.caption, design: .rounded).weight(.black))
                .foregroundColor(Color.gold400)
                .tracking(1.4)
            Text("Na tréning a súťaž")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func toolRow(icon: String, title: String, subtitle: String, badge: String? = nil,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HomeRow(icon: icon, title: title, subtitle: subtitle, badge: badge)
        }
        .buttonStyle(.pressable(scale: 0.98))
    }
}
