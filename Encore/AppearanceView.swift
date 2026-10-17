import SwiftUI

// MARK: - Profil → Vzhľad (Plus)
/// The card's leather (also in Apple Wallet) and the frame around the profile photo (BRAND_GUIDELINES §1A).
/// Free sees every option and keeps Karmín and no frame; a Plus option opens the paywall.
struct AppearanceView: View {
    @ObservedObject private var appearance = AppearanceStore.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @ObservedObject private var profileStore = UserProfileStore.shared
    @ObservedObject private var authManager = AuthManager.shared
    @State private var showPaywall = false
    @Namespace private var selection

    private var hasPlus: Bool { subscriptionManager.currentTier >= .plus }

    var body: some View {
        ZStack {
            EllegancePageBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if AppIconChoice.available.count > 1 { iconSection }
                    themeSection
                    frameSection
                    if !hasPlus {
                        Text("Karmín a profilovka bez rámika sú zadarmo, ostatné ikony, motívy a rámiky sú v Plus.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
        }
        .navigationTitle("Vzhľad")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { SubscriptionPaywallView(initialTier: .plus) }
        .sensoryFeedback(.selection, trigger: appearance.chosenTheme)
        .sensoryFeedback(.selection, trigger: appearance.chosenFrame)
        .sensoryFeedback(.success, trigger: appearance.appIcon)
        // Without Plus the free look comes back everywhere, also in Apple Wallet and on the Home Screen.
        .onAppear { appearance.applyFreeLookIfNeeded() }
    }

    // MARK: App icon
    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "IKONA APPKY", systemImage: "app.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(AppIconChoice.available) { icon in
                        iconTile(icon)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
    }

    private func iconTile(_ icon: AppIconChoice) -> some View {
        let isOn = appearance.appIcon == icon
        let locked = !hasPlus && !icon.isFree
        return Button {
            if locked { showPaywall = true } else { Task { await appearance.select(icon) } }
        } label: {
            VStack(spacing: 8) {
                if let preview = icon.preview {
                    Image(uiImage: preview)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(isOn ? Color.gold400 : Color.white.opacity(0.12), lineWidth: isOn ? 2.5 : 1)
                        }
                        .scaleEffect(isOn ? 1.06 : 1)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isOn)
                }
                HStack(spacing: 3) {
                    if locked { Image(systemName: "lock.fill").font(.caption2) }
                    Text(icon.title).font(.caption.weight(isOn ? .bold : .medium))
                }
                .foregroundColor(isOn ? Color.gold300 : .white.opacity(0.75))
            }
        }
        .buttonStyle(.pressable(scale: 0.92))
        .accessibilityLabel("Ikona \(icon.title)")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: Card
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "MOTÍV KARTY", systemImage: "wallet.pass.fill")
            Text("Platí pre kartu v Encore aj v Apple Peňaženke.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(CardTheme.allCases) { theme in
                    themeTile(theme)
                }
            }
        }
    }

    private func themeTile(_ theme: CardTheme) -> some View {
        let isOn = appearance.theme == theme
        let locked = !hasPlus && !theme.isFree
        return Button {
            if locked { showPaywall = true } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { appearance.select(theme) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                LeatherCardSurface(isFront: true, theme: theme)
                    .aspectRatio(1.72, contentMode: .fit)
                    .overlay(alignment: .topLeading) {
                        Text("ENCORE")
                            .font(.system(.caption, design: .serif).weight(.bold))
                            .tracking(2)
                            .foregroundColor(Color.gold300)
                            .padding(10)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        if isOn {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.gold400, lineWidth: 2)
                                .matchedGeometryEffect(id: "theme", in: selection)
                        }
                    }
                HStack(spacing: 6) {
                    Text(theme.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Spacer()
                    if locked { lockBadge } else if isOn { checkmark }
                }
            }
        }
        .buttonStyle(.pressable(scale: 0.96))
        .accessibilityLabel(theme.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityHint(locked ? "V Plus" : "")
    }

    // MARK: Frame
    private var frameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "RÁMIK PROFILOVKY", systemImage: "person.crop.circle")
            HStack(spacing: 12) {
                ForEach(AvatarFrame.allCases) { frame in
                    frameTile(frame)
                }
            }
        }
    }

    private func frameTile(_ frame: AvatarFrame) -> some View {
        let isOn = appearance.frame == frame
        let locked = !hasPlus && !frame.isFree
        return Button {
            if locked { showPaywall = true } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { appearance.select(frame) }
            }
        } label: {
            VStack(spacing: 8) {
                ProfileAvatarView(name: profileStore.currentName, imagePath: profileStore.currentAvatarPath,
                                  avatarURL: authManager.userAvatarURL, size: 60)
                    .avatarFrame(frame, size: 60)
                    .padding(4)
                    .background {
                        if isOn {
                            Circle().fill(Color.gold400.opacity(0.16))
                                .matchedGeometryEffect(id: "frame", in: selection)
                        }
                    }
                HStack(spacing: 3) {
                    if locked { Image(systemName: "lock.fill").font(.caption2) }
                    Text(frame.title)
                        .font(.caption.weight(isOn ? .bold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundColor(isOn ? Color.gold300 : .white.opacity(0.75))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pressable(scale: 0.92))
        .accessibilityLabel(frame.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var lockBadge: some View {
        Text("PLUS")
            .font(.system(.caption2, design: .rounded).weight(.black))
            .foregroundColor(Color.obsidian900)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.gold400, in: Capsule())
    }

    private var checkmark: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundColor(Color.gold400)
            .transition(.scale.combined(with: .opacity))
    }
}
