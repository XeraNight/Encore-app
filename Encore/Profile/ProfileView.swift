import SwiftUI
import SwiftData
import StoreKit

// MARK: - Profile tab ("Profil")
/// Who I am and my dancing world, grouped by purpose (BRAND_GUIDELINES §1A):
/// header → account → dance world (connections, competitions, tools) → membership → card →
/// library → settings. Each destination is its own screen.
struct ProfileView: View {
    @ObservedObject private var appearance = AppearanceStore.shared
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.updatedAt, order: .reverse) private var routines: [Routine]
    /// Counted in the database when Profile opens, not by loading every figure and redrawing.
    @State private var libraryCounts = ProfileLibraryCounts()

    @ObservedObject private var profileStore = UserProfileStore.shared
    @ObservedObject private var authManager = AuthManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var connectionManager = ConnectionManager.shared
    @ObservedObject private var competitionManager = CompetitionManager.shared

    @State private var showEditProfile = false
    @State private var showPaywall = false
    @State private var showManageSubscriptions = false
    @State private var copyCount = 0
    @State private var showCopied = false

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        accountCard
                        danceWorldSection
                        membershipSection
                        HomeRowGroup(title: "MOJA KARTA") {
                            NavigationLink { MemberCardScreen() } label: {
                                HomeRow(icon: "wallet.pass.fill", title: "Digitálna karta", subtitle: "QR na prepojenie a Apple Peňaženka")
                            }
                            .buttonStyle(.pressable(scale: 0.98))
                            HomeRowDivider()
                            NavigationLink { AppearanceView() } label: {
                                HomeRow(icon: "paintpalette.fill", title: "Vzhľad", subtitle: "Ikona appky, motív karty a rámik profilovky",
                                        badge: subscriptionManager.currentTier >= .plus ? nil : "PLUS")
                            }
                            .buttonStyle(.pressable(scale: 0.98))
                        }
                        librarySection
                        HomeRowGroup {
                            NavigationLink { ProfileSettingsView() } label: {
                                HomeRow(icon: "gearshape.fill", title: "Nastavenia", subtitle: "Účet, prihlásenie, upozornenia, dáta a pomoc")
                            }
                            .buttonStyle(.pressable(scale: 0.98))
                        }

                        // Room for the tab bar
                        Spacer().frame(height: 120)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showEditProfile) { ProfileEditSheet() }
            .sheet(isPresented: $showPaywall) { SubscriptionPaywallView() }
            .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
            .onAppear {
                profileStore.refreshForActiveUser()
                libraryCounts = ProfileLibraryCounts(context: modelContext)
            }
            .task(id: copyCount) {
                guard copyCount > 0 else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showCopied = true }
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeOut(duration: 0.3)) { showCopied = false }
            }
            .sensoryFeedback(.success, trigger: copyCount)
            .environment(\.locale, Locale(identifier: "sk"))
        }
    }

    // MARK: Header
    private var header: some View {
        VStack(spacing: 12) {
            Button { showEditProfile = true } label: {
                ProfileAvatarView(
                    name: profileStore.currentName,
                    imagePath: profileStore.currentAvatarPath,
                    avatarURL: authManager.userAvatarURL,
                    size: 96
                )
                .avatarFrame(appearance.frame, size: 96)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color.obsidian900)
                        .frame(width: 30, height: 30)
                        .background(Color.gold400, in: Circle())
                        .offset(x: 2, y: 2)
                }
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Upraviť profil")

            VStack(spacing: 4) {
                Text(profileStore.currentName)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text(profileStore.currentClub.isEmpty ? "Klub zatiaľ nenastavený" : profileStore.currentClub)
                    .font(.footnote.weight(.medium))
                    .foregroundColor(Color.white.opacity(profileStore.currentClub.isEmpty ? 0.55 : 0.75))
            }

            HStack(spacing: 8) {
                if AppFeatures.coachTools {
                    Label(profileStore.isCoach ? "Tréner" : "Tanečník",
                          systemImage: profileStore.isCoach ? "person.badge.shield.checkmark.fill" : "figure.dance")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .background(Color.white.opacity(0.08), in: Capsule())
                        .contentTransition(.opacity)
                }

                Button {
                    UIPasteboard.general.string = profileStore.dancerCode
                    copyCount += 1
                } label: {
                    Label(showCopied ? "Skopírované" : profileStore.dancerCode,
                          systemImage: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundColor(Color.gold400)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 30)
                        .background(Color.gold500.opacity(0.14), in: Capsule())
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("ID tanečníka \(profileStore.dancerCode)")
                .accessibilityHint("Skopíruje ID tanečníka, aby ťa partner mohol pridať")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var accountCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color.syncEmerald)
                .frame(width: 36, height: 36)
                .background(Color.syncEmerald.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(authManager.userEmail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("Prihlásený · zostavy sa synchronizujú")
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color.syncEmerald)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .homeCard()
        .accessibilityElement(children: .combine)
    }

    // MARK: Dance world: connections, competitions, tools
    private var connectionsSubtitle: String {
        let parts = [
            connectionManager.activePartners.count > 0
                ? slovakCount(connectionManager.activePartners.count, one: "partner", few: "partneri", many: "partnerov") : nil,
            connectionManager.activeConnections.count > 0
                ? slovakCount(connectionManager.activeConnections.count, one: "spojenie", few: "spojenia", many: "spojení") : nil,
            AppFeatures.coachTools && connectionManager.activeCoaches.count > 0
                ? slovakCount(connectionManager.activeCoaches.count, one: "tréner", few: "tréneri", many: "trénerov") : nil,
            AppFeatures.coachTools && connectionManager.activeStudents.count > 0
                ? slovakCount(connectionManager.activeStudents.count, one: "žiak", few: "žiaci", many: "žiakov") : nil
        ].compactMap { $0 }
        if parts.isEmpty {
            return "Spoj sa s kamarátmi z tanca cez QR kód alebo ID tanečníka"
        }
        return parts.joined(separator: " · ")
    }

    /// Only numbers KSIS shows; nothing about how far the next class is.
    private var competitionsSubtitle: String {
        guard let couple = competitionManager.activeCouple else {
            return "Prepoj pár s KSIS: trieda, body a výsledky"
        }
        let line = couple.standingsLine
        return line.isEmpty ? couple.title : line
    }

    private var danceWorldSection: some View {
        HomeRowGroup(title: "TANEČNÝ SVET") {
            NavigationLink { FriendsListView() } label: {
                HomeRow(
                    icon: "person.2.fill",
                    title: "Prepojenia",
                    subtitle: connectionsSubtitle,
                    badge: connectionManager.incomingRequests.isEmpty ? nil : "\(connectionManager.incomingRequests.count) nové"
                )
            }
            .buttonStyle(.pressable(scale: 0.98))

            HomeRowDivider()

            NavigationLink { CompetitionTrackerView() } label: {
                HomeRow(icon: "trophy.fill", title: "Súťaže a body", subtitle: competitionsSubtitle)
            }
            .buttonStyle(.pressable(scale: 0.98))

            HomeRowDivider()

            // For everyone; the student roster inside shows only for coaches.
            NavigationLink { StudioToolsView() } label: {
                HomeRow(
                    icon: "wrench.and.screwdriver.fill",
                    title: "Nástroje",
                    subtitle: profileStore.isCoach
                        ? "Zverenci, zrkadlo, metronóm a strih lekcie"
                        : "Zrkadlo, metronóm a strih lekcie"
                )
            }
            .buttonStyle(.pressable(scale: 0.98))
        }
    }

    // MARK: Membership
    private var membershipSection: some View {
        let tier = subscriptionManager.currentTier
        return VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "ČLENSTVO")

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: tier.iconName)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(tier.badgeColor)
                        .frame(width: 40, height: 40)
                        .background(tier.badgeColor.opacity(0.16), in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Encore \(tier.rawValue)")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundColor(.white)
                            .contentTransition(.opacity)
                        Text(tier.shortDescription)
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.65))
                            .lineLimit(2)
                    }
                }

                HStack(spacing: 10) {
                    Button { showPaywall = true } label: {
                        Text(tier == .premium ? "Porovnať plány" : "Vylepšiť plán")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(Color.obsidian900)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 40)
                            .background(
                                LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.pressable)

                    if subscriptionManager.entitlementSource == .storeKit {
                        // Downgrade or cancel happens in Apple's own subscription screen.
                        Button { showManageSubscriptions = true } label: {
                            Text("Zmeniť alebo zrušiť")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 40)
                                .background(Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
            .padding(14)
            .homeCard()
        }
    }

    // MARK: Library
    private var librarySection: some View {
        HomeRowGroup(title: "MOJA KNIŽNICA") {
            NavigationLink {
                ProfileRoutinesListView(routines: routines)
            } label: {
                HomeRow(icon: "figure.dance", title: "Zostavy", detail: "\(routines.count)")
            }
            .buttonStyle(.pressable(scale: 0.98))

            HomeRowDivider()

            NavigationLink {
                ProfileFiguresListView()
            } label: {
                HomeRow(icon: "book.closed.fill", title: "Knižnica figúr", detail: "\(libraryCounts.figures)")
            }
            .buttonStyle(.pressable(scale: 0.98))

            HomeRowDivider()

            NavigationLink {
                ProfileMediaListView()
            } label: {
                HomeRow(icon: "video.fill", title: "Videá a poznámky", detail: "\(libraryCounts.media)")
            }
            .buttonStyle(.pressable(scale: 0.98))
        }
    }
}

// MARK: - Member card screen
/// The digital member card on its own screen: QR for connecting and Apple Wallet.
struct MemberCardScreen: View {
    @ObservedObject private var profileStore = UserProfileStore.shared

    var body: some View {
        ZStack {
            EllegancePageBackground()
            ScrollView {
                EncoreMemberCardView(
                    name: profileStore.currentName,
                    club: profileStore.currentClub,
                    allowInteractiveTilt: true,
                    showActionButtons: true
                )
                .padding(20)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Moja karta")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Profil") {
    ProfileView()
        .previewWithSampleData()
}
