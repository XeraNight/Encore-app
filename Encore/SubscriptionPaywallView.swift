import SwiftUI
import StoreKit

// MARK: - Plans (Plus, Premium)
/// The paywall promises only what works today (App Review 2.3.1 and 3.1.2, docs/V1_PAYWALL_FEATURES_PLAN.md).
/// A feature gets a row here when it is finished, never before. Prices come from the App Store.
public struct SubscriptionPaywallView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isAnnual = true
    @State private var selectedTier: SubscriptionTier
    @State private var errorMessage: String?
    @State private var showLegalSheet = false
    @State private var choiceTaps = 0

    public init(initialTier: SubscriptionTier = .plus) {
        _selectedTier = State(initialValue: initialTier == .free ? .plus : initialTier)
    }

    struct Feature: Identifiable {
        let icon: String
        let title: String
        let detail: String
        var id: String { title }
    }

    /// What each plan adds. Keep in step with the code that gates it.
    static func features(for tier: SubscriptionTier) -> [Feature] {
        // Features held back in `AppFeatures` are not offered.
        let coach = AppFeatures.coachTools
        let videos = AppFeatures.sharedVideos
        switch tier {
        case .plus:
            return [
                Feature(icon: "square.stack.3d.up.fill", title: "Neobmedzené zostavy",
                        detail: "Viac zostáv na každý tanec. Free má jednu."),
                Feature(icon: "target", title: "Top 3 priority po lekcii",
                        detail: "Tri hlavné korekcie trénera pre každý tanec. Máš ich na Domove, kým ich nezvládneš."),
                Feature(icon: "chart.bar.xaxis", title: "Moja sezóna",
                        detail: "Z tvojich výsledkov v KSIS: v ktorom tanci dostávaš najmenej krížikov, finále a vývoj počas sezóny."),
                Feature(icon: "chart.bar.fill", title: "Vývoj tréningov",
                        detail: "Hodiny po týždňoch, mesiace sezóny, tance, ktoré riešiš najviac, a zvládnuté priority."),
                Feature(icon: "list.number", title: "Súťažný deň",
                        detail: "Tance v poradí a pri každom tvoje Top 3 od trénera. Pred kolom si ich prečítaš za 10 sekúnd."),
                Feature(icon: "paintpalette.fill", title: "Vzhľad",
                        detail: "Ikony appky, motívy karty v Encore aj v Apple Peňaženke a rámiky profilovky."),
                Feature(icon: "scissors", title: "Strih lekcie na figúry",
                        detail: "Hodinové video z lekcie rozdelíš na figúry a uložíš ich k zostave."),
                coach ? Feature(icon: "key.fill", title: "Kľúče pre hosťujúcich trénerov",
                                detail: "Požičaj zostavu viacerým trénerom naraz a až na 30 dní. Free má jeden kľúč na 7 dní.") : nil,
                videos ? Feature(icon: "icloud.and.arrow.up.fill", title: "10 GB na zdieľané videá",
                                 detail: "Pre partnera a trénera. Free má 1 GB.") : nil,
            ].compactMap { $0 }
        case .premium:
            return [
                Feature(icon: "checkmark.seal.fill", title: "Všetko z Plus",
                        detail: coach ? "Zostavy, Top 3 priority, kľúče pre trénerov a ďalšie." : "Neobmedzené zostavy, Top 3 priority a strih lekcie."),
                Feature(icon: "square.on.square", title: "Porovnanie so vzorom",
                        detail: "Vzor priesvitne cez tvoje video, olovnica, sklon ramien a korekcie uložené k figúre."),
                Feature(icon: "clock.arrow.circlepath", title: "Časová os figúry",
                        detail: "Všetky zábery figúry podľa dátumu. Prvý a posledný vedľa seba jedným ťuknutím."),
                coach ? Feature(icon: "clock.arrow.circlepath", title: "Pre trénerov: čo sme robili naposledy",
                                detail: "Pri každom zverencovi zápis z poslednej lekcie. Vidíš ho len ty.") : nil,
                videos ? Feature(icon: "icloud.and.arrow.up.fill", title: "50 GB na zdieľané videá",
                                 detail: "Pre partnera a trénera.") : nil,
            ].compactMap { $0 }
        case .free:
            return []
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        header
                        billingPicker
                        HStack(spacing: 12) {
                            tierCard(.plus)
                            tierCard(.premium)
                        }
                        featuresCard
                        purchaseSection
                        footer
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Členstvo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .accessibilityLabel("Zavrieť")
                }
            }
            .sheet(isPresented: $showLegalSheet) { LegalComplianceView() }
            .sensoryFeedback(.selection, trigger: choiceTaps)
            .task {
                AnalyticsManager.shared.paywallViewed(source: "paywall_modal", initialTier: selectedTier.rawValue)
                await subscriptionManager.loadProducts()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Header
    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: selectedTier.iconName)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [Color.gold300, Color.gold500], startPoint: .topLeading, endPoint: .bottomTrailing))
                .contentTransition(.symbolEffect(.replace))
                .shadow(color: Color.gold500.opacity(0.45), radius: 12, y: 4)
            Text("Viac času na tanec")
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundColor(.white)
            Text(AppFeatures.coachTools
                 ? "Free ti ostane navždy: poznámky, plátno, výsledky z KSIS, zdieľanie s partnerom a kľúč pre hosťujúceho trénera. Plus a Premium pridávajú pohodlie a analýzu."
                 : "Free ti ostane navždy: poznámky, plátno, výsledky z KSIS a spoločné zostavy s partnerom. Plus a Premium pridávajú pohodlie a analýzu.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Billing
    private var billingPicker: some View {
        HStack(spacing: 4) {
            billingOption("Mesačne", annual: false)
            billingOption(savingsText.map { "Ročne · \($0)" } ?? "Ročne", annual: true)
        }
        .padding(4)
        .homeCard(cornerRadius: 16)
    }

    private func billingOption(_ title: String, annual: Bool) -> some View {
        let isOn = isAnnual == annual
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isAnnual = annual }
            choiceTaps += 1
        } label: {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundColor(isOn ? Color.obsidian900 : .white.opacity(0.75))
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(isOn ? AnyShapeStyle(Color.gold400) : AnyShapeStyle(Color.clear), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: Tiers
    private func tierCard(_ tier: SubscriptionTier) -> some View {
        let isSelected = selectedTier == tier
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedTier = tier }
            choiceTaps += 1
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: tier.iconName)
                        .foregroundColor(isSelected ? Color.gold400 : .white.opacity(0.6))
                    Spacer()
                    if subscriptionManager.currentTier == tier {
                        Text("TVOJ PLÁN")
                            .font(.system(.caption2, design: .rounded).weight(.black))
                            .foregroundColor(Color.obsidian900)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gold400, in: Capsule())
                    }
                }
                Text(tier.rawValue)
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundColor(.white)
                Text(price(for: tier, annual: isAnnual))
                    .font(.system(.headline, design: .rounded).weight(.black))
                    .foregroundColor(Color.gold300)
                    .contentTransition(.numericText())
                Text(isAnnual ? (monthlyEquivalent(for: tier).map { "ročne · \($0) mesačne" } ?? "ročne") : "mesačne")
                    .font(.caption2)
                    .foregroundColor(Color.textSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCard(cornerRadius: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.gold400 : Color.clear, lineWidth: 1.8)
            )
            .shadow(color: isSelected ? Color.gold500.opacity(0.2) : .clear, radius: 10, y: 4)
        }
        .buttonStyle(.pressable(scale: 0.97))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var featuresCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(title: "ČO DOSTANEŠ S \(selectedTier.rawValue.uppercased())", systemImage: "sparkles")
            ForEach(Self.features(for: selectedTier)) { feature in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color.gold400)
                        .frame(width: 34, height: 34)
                        .background(Color.gold500.opacity(0.16), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(.white)
                        Text(feature.detail)
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .homeCard(cornerRadius: 20)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTier)
    }

    // MARK: Purchase
    @ViewBuilder
    private var purchaseSection: some View {
        VStack(spacing: 10) {
            if subscriptionManager.isAppOwner {
                Label("Si majiteľ appky, máš všetko.", systemImage: "crown.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color.gold300)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .homeCard(cornerRadius: 16)
            } else if subscriptionManager.currentTier == selectedTier {
                Label("Tento plán už máš", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color.syncEmerald)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .homeCard(cornerRadius: 16)
            } else {
                PrimarySheetButton(
                    title: "Pokračovať s \(selectedTier.rawValue)",
                    isLoading: subscriptionManager.isPurchasing,
                    isEnabled: true,
                    action: purchase
                )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.medium))
                    .foregroundColor(Color.latinRed)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    errorMessage = nil
                    await subscriptionManager.restorePurchases()
                }
            } label: {
                Text("Obnoviť nákupy")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.gold300)
                    .frame(minHeight: 44)
            }

            Text("Predplatné sa obnovuje automaticky, kým ho nezrušíš aspoň 24 hodín pred koncom obdobia. Spravuješ ho v Nastaveniach iPhonu pod svojím Apple ID.")
                .font(.caption2)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Podmienky používania") { showLegalSheet = true }
                Text("·").foregroundColor(.white.opacity(0.3))
                Button("Ochrana súkromia") { showLegalSheet = true }
            }
            .font(.caption.weight(.medium))
            .foregroundColor(.white.opacity(0.65))
        }
    }

    // MARK: Prices from the App Store
    private func product(for tier: SubscriptionTier, annual: Bool) -> Product? {
        let id: String
        switch (tier, annual) {
        case (.plus, true): id = SubscriptionManager.ProductID.plusAnnual
        case (.plus, false): id = SubscriptionManager.ProductID.plusMonthly
        case (.premium, true): id = SubscriptionManager.ProductID.premiumAnnual
        case (.premium, false): id = SubscriptionManager.ProductID.premiumMonthly
        case (.free, _): return nil
        }
        return subscriptionManager.availableProducts.first { $0.id == id }
    }

    /// Always the App Store's price in the viewer's own currency; until it answers, "…" (a price typed into the app
    /// would show euros to someone who pays in dollars).
    private func price(for tier: SubscriptionTier, annual: Bool) -> String {
        product(for: tier, annual: annual)?.displayPrice ?? "…"
    }

    /// "4,17 €" for the annual price spread over twelve months; nil until the App Store answers.
    private func monthlyEquivalent(for tier: SubscriptionTier) -> String? {
        guard let annual = product(for: tier, annual: true) else { return nil }
        return (annual.price / 12).formatted(annual.priceFormatStyle)
    }

    /// "−30 %" for the selected plan; nil until the App Store answers.
    private var savingsText: String? {
        guard let monthly = product(for: selectedTier, annual: false), let annual = product(for: selectedTier, annual: true),
              monthly.price > 0 else { return nil }
        let full = NSDecimalNumber(decimal: monthly.price * 12).doubleValue
        let saving = 1 - NSDecimalNumber(decimal: annual.price).doubleValue / full
        guard saving > 0.01 else { return nil }
        return "−\(Int((saving * 100).rounded())) %"
    }

    private func purchase() {
        errorMessage = nil
        guard let product = product(for: selectedTier, annual: isAnnual) else {
            errorMessage = "Predplatné sa práve nedá načítať z App Store. Skús to o chvíľu."
            return
        }
        AnalyticsManager.shared.subscriptionUpgradeInitiated(tier: selectedTier.rawValue, isAnnual: isAnnual)
        Task {
            do {
                if try await subscriptionManager.purchase(product: product) {
                    AnalyticsManager.shared.subscriptionPurchased(tier: selectedTier.rawValue, isAnnual: isAnnual)
                    dismiss()
                }
            } catch {
                errorMessage = "Nákup sa nepodaril: \(error.localizedDescription)"
            }
        }
    }
}

#Preview("Členstvo") {
    SubscriptionPaywallView(initialTier: .premium)
        .previewWithSampleData()
}
