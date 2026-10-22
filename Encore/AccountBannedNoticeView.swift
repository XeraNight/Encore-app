import SwiftUI

// MARK: - Account Banned / Suspended Notice View
struct AccountBannedNoticeView: View {
    let reason: String
    var onSignOut: () -> Void
    
    var body: some View {
        ZStack {
            Color.obsidian900.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Red Lock Icon Badge
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 96, height: 96)
                    
                    Circle()
                        .stroke(Color.red.opacity(0.4), lineWidth: 2)
                        .frame(width: 96, height: 96)
                    
                    Image(systemName: "lock.slash.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.red)
                }
                
                VStack(spacing: 8) {
                    Text("Účet bol pozastavený")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Tvoj prístup k aplikácii Encore bol dočasne alebo trvalo zablokovaný administrátorom.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Reason Card
                VStack(alignment: .leading, spacing: 8) {
                    Label("Uvedený dôvod:", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.gold400)
                    
                    Text(reason.isEmpty ? "Porušenie Podmienok používania alebo pravidiel komunity." : reason)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white)
                        .lineSpacing(3)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
                .padding(.horizontal, 28)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        if let url = AppContact.mailURL(subject: "Odvolanie voči pozastaveniu účtu") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                            Text("Kontaktovať podporu")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.gold400)
                        .cornerRadius(25)
                    }
                    
                    Button {
                        onSignOut()
                    } label: {
                        Text("Odhlásiť sa z účtu")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
    }
}
