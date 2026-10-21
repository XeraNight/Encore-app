import SwiftUI

// MARK: - Deferred Deep Link Paste Sheet (Zero tracking, Native SwiftUI PasteButton)
// Safely reads copied invite links without triggering iOS system permission alerts.
struct DeferredInvitePasteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var manualCode: String = ""
    @ObservedObject private var friendManager = FriendManager.shared
    
    var body: some View {
        ZStack {
            Color.obsidian900.ignoresSafeArea()
            
            // Ambient Radial Light
            RadialGradient(
                colors: [Color.gold500.opacity(0.18), Color.clear],
                center: .top,
                startRadius: 20,
                endRadius: 320
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                
                // Icon & Title
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.gold500.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "person.badge.plus.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color.gold400)
                    }
                    
                    Text("Prišiel si cez pozvánku?")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("V schránke bola nájdená linka. Ťukni na Vložiť a Encore ťa okamžite prepojí s tvojím tanečným partnerom.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                // Native iOS PasteButton (Zero permission alert, explicit user gesture)
                VStack(spacing: 8) {
                    PasteButton(payloadType: URL.self) { urls in
                        if let url = urls.first {
                            HapticFeedback.success()
                            dismiss()
                            friendManager.applyPastedURL(url)
                        }
                    }
                    .tint(Color.gold400)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    
                    Text("Ťuknutím vložíš odkaz na pozvánku zo schránky")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.45))
                }
                .padding(.vertical, 8)
                
                // Divider with text
                HStack {
                    Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                    Text("alebo zadaj kód ručne")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.4))
                    Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                }
                .padding(.horizontal, 24)
                
                // Manual Invite Code Entry
                HStack(spacing: 10) {
                    TextField("Kód tanečníka (napr. DNC-4821)", text: $manualCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.obsidian800)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
                        .foregroundColor(.white)
                    
                    Button {
                        let clean = manualCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        if !clean.isEmpty {
                            HapticFeedback.light()
                            dismiss()
                            friendManager.processInviteCode(clean)
                        }
                    } label: {
                        Text("Pridať")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(Color.gold400)
                            .cornerRadius(12)
                    }
                    .disabled(manualCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Dismiss Button
                Button {
                    dismiss()
                } label: {
                    Text("Preskočiť")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.textSecondary)
                        .padding(.bottom, 16)
                }
            }
        }
        .presentationDetents([.fraction(0.55), .medium])
        .presentationDragIndicator(.visible)
    }
}
