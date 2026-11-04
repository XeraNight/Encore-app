import SwiftUI

// MARK: - Invite from a scanned QR code or a link (the only sheet for it, presented from EncoreApp)
/// Shows who invites (name, club and ID from the link, never this account's own card) and sends them a request;
/// they confirm it on their side (BRAND_GUIDELINES §1A).
struct FriendInviteSheetView: View {
    let invite: FriendInvitePayload
    let onDismiss: () -> Void

    @State private var isSent = false
    @ObservedObject private var friendManager = FriendManager.shared

    var body: some View {
        ZStack {
            EllegancePageBackground()
            VStack(spacing: 22) {
                if isSent {
                    sentContent
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                } else {
                    inviteContent
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 20)
        }
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: isSent)
    }

    // MARK: Invite
    private var inviteContent: some View {
        VStack(spacing: 22) {
            HomeSectionHeader(title: "NOVÉ SPOJENIE", systemImage: "person.2.fill")

            VStack(spacing: 10) {
                ProfileAvatarView(name: invite.name, imagePath: nil, avatarURL: invite.avatarURL, size: 76)
                Text(invite.name)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                if !invite.club.isEmpty {
                    Text(invite.club)
                        .font(.subheadline)
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                Text(invite.displayId)
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundColor(Color.gold300)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.gold500.opacity(0.12), in: Capsule())
                if !invite.dancerGroups.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(invite.dancerGroups, id: \.self) { group in
                            Text(group)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .homeCard(cornerRadius: 10)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .homeCard()

            Text("Pošli žiadosť o spojenie. Keď ju potvrdí, budete spojení.")
                .font(.footnote)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if let error = friendManager.inviteErrorMessage {
                SheetBanner(text: error, isError: true)
            }
            PrimarySheetButton(title: "Poslať žiadosť o spojenie", isLoading: friendManager.isProcessingInvite, isEnabled: true) {
                Task {
                    if await friendManager.respondToIncomingInvite(accept: true) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isSent = true }
                    }
                }
            }
            .accessibilityIdentifier("invite.send")
            Button(action: onDismiss) {
                Text("Neskôr")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.pressable)
        }
    }

    // MARK: Sent
    private var sentContent: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 54, weight: .bold))
                .foregroundColor(Color.gold400)
                .symbolEffect(.bounce, value: isSent)
            Text("Žiadosť odoslaná")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
            Text("Keď ju \(invite.name) potvrdí, budete spojení.")
                .font(.subheadline)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            PrimarySheetButton(title: "Hotovo", isLoading: false, isEnabled: true, action: onDismiss)
        }
    }
}
