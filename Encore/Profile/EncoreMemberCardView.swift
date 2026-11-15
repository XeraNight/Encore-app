import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Členský lístok
/// The member ticket, drawn like the pass in Apple Wallet (flat colour from Vzhľad, gold lettering, the QR code at
/// the bottom) so what the dancer sees here and in Wallet is the same. The QR code is the invite link: whoever scans
/// it can ask to connect. The name, club and ID come from the profile; the KSIS number and classes from the dancer's
/// own Súťaže, never shown as "verified" (the dancer picks the number themselves).
struct EncoreMemberCardView: View {
    @ObservedObject private var appearance = AppearanceStore.shared
    var name: String
    var club: String
    var showActionButtons: Bool = true

    /// Made once per link, not on every redraw.
    @State private var qrImage: UIImage?

    @ObservedObject private var walletManager = AppleWalletPassManager.shared
    @ObservedObject private var friendManager = FriendManager.shared
    @ObservedObject private var competitions = CompetitionManager.shared

    /// What Wallet shows: gold text, darker gold labels.
    private static let ink = Color(red: 1.0, green: 230 / 255, blue: 153 / 255)
    private static let label = Color(red: 212 / 255, green: 175 / 255, blue: 55 / 255)

    private var dancerCode: String { UserProfileStore.shared.dancerCode }

    private var ksisNumber: String? {
        competitions.dancer.map { String($0.personNumber) }
    }

    private var classesText: String? {
        guard let couple = competitions.activeCouple else { return nil }
        let parts = [("ŠTT", couple.stt.className), ("LAT", couple.lat.className)].compactMap { label, name in name.map { "\(label) \($0)" } }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var groupsText: String? {
        let groups = UserProfileStore.shared.dancerGroups
        return groups.isEmpty ? nil : groups.joined(separator: " · ")
    }

    private var qrString: String { friendManager.buildMemberCardURL() }

    var body: some View {
        VStack(spacing: 20) {
            ticket
            if showActionButtons { actions }
        }
        // Why the ticket could not go to Apple Wallet.
        .alert(walletManager.alertTitle, isPresented: $walletManager.showErrorAlert) {
            Button("Rozumiem", role: .cancel) {}
        } message: {
            Text(walletManager.alertMessage)
        }
        .task { await FriendManager.shared.fetchOrGenerateInviteToken() }
        .task(id: qrString) {
            let link = qrString
            qrImage = await Task.detached(priority: .utility) { QRGenerator.generateQRCode(from: link) }.value
        }
    }

    // MARK: Ticket
    private var ticket: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                HStack(spacing: 8) {
                    Image("EncoreLogo")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(width: 26, height: 26)
                    Text("ENCORE")
                        .font(.system(.subheadline, design: .serif).weight(.bold))
                        .tracking(2.4)
                }
                .foregroundColor(Self.ink)
                Spacer()
                if !dancerCode.isEmpty {
                    field("ID TANEČNÍKA", dancerCode, alignment: .trailing, mono: true)
                }
            }

            field("TANEČNÍK", name.isEmpty ? "Tanečník" : name, large: true)

            HStack(alignment: .top, spacing: 16) {
                field("KLUB", club.isEmpty ? "Individuálny" : club)
                if let ksisNumber {
                    field("KSIS Č.", ksisNumber, mono: true)
                }
            }
            if classesText != nil || groupsText != nil {
                HStack(alignment: .top, spacing: 16) {
                    if let classesText { field("TRIEDY", classesText) }
                    if let groupsText { field("SKUPINY", groupsText) }
                }
            }

            qrBox
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: 360, alignment: .leading)
        .background(appearance.theme.middle, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Self.label.opacity(0.25), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.55), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
    }

    private func field(_ title: String, _ value: String, alignment: HorizontalAlignment = .leading,
                       large: Bool = false, mono: Bool = false) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.9)
                .foregroundColor(Self.label)
            Text(value)
                .font(large ? .system(size: 28, weight: .semibold, design: .serif)
                            : .system(size: 15, weight: .semibold, design: mono ? .monospaced : .default))
                .foregroundColor(Self.ink)
                .lineLimit(large ? 2 : 1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }

    private var qrBox: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white)
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                } else {
                    ProgressView().tint(.black)
                }
            }
            .frame(width: 168, height: 168)
            .accessibilityLabel("QR kód na pridanie do spojení")
            Text("Naskenuj a pošli žiadosť o spojenie")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Self.label)
        }
    }

    // MARK: Actions
    private var actions: some View {
        VStack(spacing: 12) {
            // In Wallet: open it there or refresh it (new look); otherwise add it.
            if walletManager.isPassInWallet {
                HStack(spacing: 8) {
                    Button {
                        HapticFeedback.light()
                        walletManager.openInWallet()
                    } label: {
                        Label("Otvoriť v Peňaženke", systemImage: "wallet.pass.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .homeCard(cornerRadius: 14)
                    }
                    .buttonStyle(.pressable(scale: 0.97))

                    Button {
                        Task { await walletManager.updatePassInWallet(userInitiated: true) }
                    } label: {
                        Group {
                            if walletManager.isLoadingPass {
                                ProgressView().tint(Color.gold400)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color.gold400)
                            }
                        }
                        .frame(width: 50, height: 48)
                        .homeCard(cornerRadius: 14)
                    }
                    .buttonStyle(.pressable(scale: 0.92))
                    .disabled(walletManager.isLoadingPass)
                    .accessibilityLabel("Aktualizovať lístok v Peňaženke")
                }
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            } else if AppleWalletPassManager.canIssuePasses {
                Button {
                    HapticFeedback.medium()
                    Task { await walletManager.addCardToAppleWallet() }
                } label: {
                    Label(walletManager.isLoadingPass ? "Pripravujem lístok..." : "Pridať do Apple Peňaženky", systemImage: "wallet.pass.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.gold400, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.pressable(scale: 0.97))
                .disabled(walletManager.isLoadingPass)
            }

            HStack(spacing: 8) {
                action("Poslať", icon: "square.and.arrow.up") { share() }
                action("Kopírovať ID", icon: "doc.on.doc") {
                    UIPasteboard.general.string = dancerCode
                    HapticFeedback.light()
                }
                .disabled(dancerCode.isEmpty)
                action("Nový QR", icon: "arrow.clockwise", isBusy: friendManager.isRefreshingToken) {
                    Task { await FriendManager.shared.refreshInviteToken() }
                }
            }

            Text("\(AppFeatures.coachTools ? "Partner alebo tréner" : "Partner") naskenuje QR kód a pošle ti žiadosť o spojenie. Kód platí 30 dní, nový zneplatní ten starý\(walletManager.isPassInWallet ? " a lístok v Peňaženke ho dostane sám" : "").")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        }
        .frame(maxWidth: 360)
    }

    private func action(_ title: String, icon: String, isBusy: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Group {
                    if isBusy {
                        ProgressView().tint(Color.gold400)
                    } else {
                        Image(systemName: icon)
                            .font(.subheadline.weight(.bold))
                    }
                }
                .frame(height: 20)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(Color.gold300)
            .frame(maxWidth: .infinity, minHeight: 58)
            .homeCard(cornerRadius: 14)
        }
        .buttonStyle(.pressable(scale: 0.95))
    }

    // MARK: Share
    private func share() {
        HapticFeedback.medium()
        let text = "Tanečné spojenie v Encore: \(name.isEmpty ? "Tanečník" : name)"
        let items: [Any] = URL(string: qrString).map { [text, $0] } ?? [text, qrString]
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(controller, animated: true)
        }
    }
}
