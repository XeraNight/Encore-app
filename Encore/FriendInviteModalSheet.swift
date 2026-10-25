import SwiftUI

// MARK: - Friend Invite Modal Sheet
// Displays inviter details and lets the user choose to ACCEPT or DECLINE the connection.
struct FriendInviteModalSheet: View {
    @ObservedObject var friendManager = FriendManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.obsidian950.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Drag indicator
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                
                if let invite = friendManager.incomingInvite {
                    VStack(spacing: 16) {
                        // Badge
                        HStack(spacing: 6) {
                            Circle().fill(Color.gold400).frame(width: 6, height: 6)
                            Text("TANEČNÉ PREPOJENIE")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .tracking(1.4)
                                .foregroundColor(Color.gold400)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gold500.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.gold500.opacity(0.3), lineWidth: 1))
                        
                        // Avatar or Monogram
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.52, green: 0.05, blue: 0.11), Color(red: 0.20, green: 0.01, blue: 0.04)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 76, height: 76)
                                .overlay(Circle().stroke(Color.gold500.opacity(0.6), lineWidth: 1.5))
                                .shadow(color: Color.black.opacity(0.5), radius: 10, y: 5)
                            
                            Text(String(invite.name.prefix(1)).uppercased())
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundColor(Color(red: 0.96, green: 0.85, blue: 0.50))
                        }
                        
                        // Inviter Details
                        VStack(spacing: 4) {
                            Text(invite.name)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(invite.club.isEmpty ? "Individuálny tanečník" : invite.club)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.textSecondary)
                            
                            // Public ID Badge
                            Text(invite.displayId)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.gold300)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .padding(.top, 4)
                        }
                        
                        // Dance Groups Chips
                        if !invite.dancerGroups.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(invite.dancerGroups, id: \.self) { group in
                                    Text(group)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(Color.white.opacity(0.85))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.obsidian800)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))
                                }
                            }
                            .padding(.top, 2)
                        }
                        
                        Text("Pozýva ťa na spojenie v Encore. Keď tvoju žiadosť potvrdí, budete spojení.")
                            .font(.system(size: 13))
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color.textSecondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // Action Buttons: Accept / Decline
                    VStack(spacing: 12) {
                        Button {
                            Task {
                                if await friendManager.respondToIncomingInvite(accept: true) {
                                    friendManager.showInviteSheet = false
                                    friendManager.incomingInvite = nil
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if friendManager.isProcessingInvite {
                                    ProgressView().tint(.black)
                                } else {
                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Poslať žiadosť")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.98, green: 0.88, blue: 0.60), Color(red: 0.83, green: 0.68, blue: 0.28)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color(red: 0.83, green: 0.68, blue: 0.28).opacity(0.35), radius: 10, y: 3)
                        }
                        .disabled(friendManager.isProcessingInvite)
                        
                        Button {
                            Task {
                                _ = await friendManager.respondToIncomingInvite(accept: false)
                            }
                        } label: {
                            Text("Odmietnuť")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .disabled(friendManager.isProcessingInvite)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(Color.gold400)
                        Text(friendManager.inviteErrorMessage ?? "Pozvánka nie je k dispozícii.")
                            .font(.system(size: 15, weight: .medium))
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color.white.opacity(0.85))
                            .padding(.horizontal, 24)
                        
                        Button("Zavrieť") {
                            friendManager.showInviteSheet = false
                            friendManager.inviteErrorMessage = nil
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.gold400)
                        .padding(.top, 12)
                    }
                    .padding(.vertical, 40)
                }
            }
        }
        .presentationDetents([.medium, .fraction(0.68)])
        .presentationDragIndicator(.visible)
    }
}
