import SwiftUI

// MARK: - Friend Invite Modal Sheet (Presented on QR scan or deep link)
struct FriendInviteSheetView: View {
    let invite: FriendInvitePayload
    let onDismiss: () -> Void
    
    @State private var isAccepted = false
    @ObservedObject private var friendManager = FriendManager.shared
    
    var body: some View {
        ZStack {
            Color.obsidian900.ignoresSafeArea()
            
            // Ambient Ruby Glow
            RadialGradient(
                colors: [Color(red: 0.62, green: 0.03, blue: 0.10).opacity(0.35), Color.clear],
                center: .top,
                startRadius: 20,
                endRadius: 360
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header Drag Indicator
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                
                if !isAccepted {
                    VStack(spacing: 8) {
                        Text("TANEČNÉ SPOJENIE")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .tracking(1.4)
                            .foregroundColor(Color.gold400)
                        
                        Text("Pozvánka do priateľov")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    // Display the Friend's Luxury Member Card
                    EncoreMemberCardView(
                        name: invite.name,
                        club: invite.club,
                        allowInteractiveTilt: true,
                        showActionButtons: false
                    )
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 6) {
                        Text(invite.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        if !invite.club.isEmpty {
                            Text("Tanečný klub: \(invite.club)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.gold300.opacity(0.8))
                        }
                        
                        Text("Chce sa s tebou spojiť v Encore.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        if let error = friendManager.inviteErrorMessage {
                            Text(error)
                                .font(.footnote.weight(.medium))
                                .foregroundColor(Color.latinRed)
                                .multilineTextAlignment(.center)
                                .transition(.opacity)
                        }

                        Button {
                            Task {
                                if await friendManager.respondToIncomingInvite(accept: true) {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { isAccepted = true }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if friendManager.isProcessingInvite {
                                    ProgressView().tint(.black)
                                } else {
                                    Image(systemName: "person.badge.plus.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Poslať žiadosť o prepojenie")
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.gold400, Color.gold500],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Color.gold500.opacity(0.35), radius: 10, y: 3)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            onDismiss()
                        } label: {
                            Text("Neskôr")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.textSecondary)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                } else {
                    // Success View
                    VStack(spacing: 20) {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(Color.gold500.opacity(0.18))
                                .frame(width: 90, height: 90)
                            
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 54, weight: .bold))
                                .foregroundColor(Color.gold400)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Žiadosť odoslaná")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Keď ju \(invite.name) potvrdí, budete spojení.")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.gold300.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 36)
                        }
                        
                        Spacer()
                        
                        Button {
                            onDismiss()
                        } label: {
                            Text("Rozumiem")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.gold400)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}
