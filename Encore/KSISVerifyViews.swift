import Combine
import SwiftUI

// MARK: - Verification in person
/// A pending dancer shows a verification QR; a verified dancer of the same KSIS club, or their partner, scans it with
/// the iPhone Camera or Encore's scanner and confirms they know them. The code is only a hint: the server decides who
/// may vouch (20261029b_ksis_vouch_in_person.sql).
enum KSISVouchLink {
    /// `encore://verify?c=<32 hex>`.
    static func url(code: String) -> URL? {
        var components = URLComponents()
        components.scheme = "encore"
        components.host = "verify"
        components.queryItems = [URLQueryItem(name: "c", value: code)]
        return components.url
    }

    static func code(from text: String) -> String? {
        guard let components = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme == "encore", components.host == "verify",
              let code = components.queryItems?.first(where: { $0.name == "c" })?.value?.lowercased(),
              code.count == 32, code.allSatisfy(\.isHexDigit) else { return nil }
        return code
    }
}

/// A scanned or opened verification QR waits here until the signed-in app shows it (MainTabView).
@MainActor
final class KSISVouchRouter: ObservableObject {
    static let shared = KSISVouchRouter()
    @Published var pendingCode: String?
}

// MARK: - The pending dancer's QR
struct KSISVerifyCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = CompetitionManager.shared

    @State private var verifyCode: KSISVerifyCode?
    @State private var qrImage: UIImage?
    @State private var errorText: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            EllegancePageBackground()
            VStack(spacing: 20) {
                HomeSectionHeader(title: "OVERENIE NAŽIVO", systemImage: "qrcode")

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let secondsLeft = verifyCode.map { Int($0.expiresAt.timeIntervalSince(context.date).rounded(.up)) } ?? 0
                    VStack(spacing: 20) {
                        codeCard(secondsLeft: secondsLeft)
                        Text("Ukáž kód overenému tanečníkovi zo svojho klubu alebo svojmu partnerovi. Naskenuje ho fotoaparátom iPhonu alebo v Encore a potvrdí, že ťa pozná osobne.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Kód je náhodný a nie sú v ňom tvoje údaje.")
                            .font(.caption)
                            .foregroundColor(Color.gold300)
                        Spacer(minLength: 0)
                        if let errorText {
                            SheetBanner(text: errorText, isError: true)
                        }
                        if verifyCode == nil || secondsLeft <= 0 {
                            PrimarySheetButton(title: "Nový kód", isLoading: isLoading, isEnabled: !isLoading) {
                                Task { await open() }
                            }
                        } else {
                            PrimarySheetButton(title: "Hotovo", isLoading: false, isEnabled: true) { dismiss() }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 20)
        }
        .presentationDragIndicator(.visible)
        .task { await open() }
        .task(id: verifyCode?.code) {
            guard let link = verifyCode.flatMap({ KSISVouchLink.url(code: $0.code) })?.absoluteString else { return }
            qrImage = await Task.detached(priority: .userInitiated) { QRGenerator.generateQRCode(from: link) }.value
        }
        // Whoever vouched did it on their iPhone; back here the diary shows the new state.
        .onDisappear { Task { await manager.loadAllData() } }
        .sensoryFeedback(.error, trigger: errorText)
    }

    private func codeCard(secondsLeft: Int) -> some View {
        VStack(spacing: 12) {
            ZStack {
                if let qrImage, secondsLeft > 0 {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityLabel("Overovací QR kód")
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                } else if verifyCode != nil, secondsLeft <= 0 {
                    Label("Kód vypršal", systemImage: "clock.badge.xmark")
                        .font(.headline)
                        .foregroundColor(Color.gold300)
                } else {
                    ProgressView().tint(Color.gold400)
                }
            }
            .frame(width: 220, height: 220)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: secondsLeft > 0)

            if secondsLeft > 0 {
                Text("Platí ešte \(voiceTimeString(TimeInterval(secondsLeft)))")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundColor(.white)
                    .contentTransition(.numericText(countsDown: true))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .homeCard()
    }

    private func open() async {
        isLoading = true
        defer { isLoading = false }
        do {
            verifyCode = try await manager.openVerifyCode()
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }
}

// MARK: - The scanner vouches
struct KSISVouchSheet: View {
    let code: String
    let onDismiss: () -> Void

    @ObservedObject private var manager = CompetitionManager.shared
    @State private var preview: KSISVouchPreview?
    @State private var errorText: String?
    @State private var isWorking = false
    @State private var isDone = false

    var body: some View {
        ZStack {
            EllegancePageBackground()
            VStack(spacing: 22) {
                if isDone, let preview {
                    doneContent(preview)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                } else {
                    askContent
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 28)
            .padding(.bottom, 20)
        }
        .presentationDragIndicator(.visible)
        .task { await load() }
        .sensoryFeedback(.success, trigger: isDone)
        .sensoryFeedback(.error, trigger: errorText)
    }

    private var askContent: some View {
        VStack(spacing: 22) {
            HomeSectionHeader(title: "OVERENIE NAŽIVO", systemImage: "person.badge.shield.checkmark")

            if let preview {
                VStack(spacing: 10) {
                    ProfileAvatarView(name: preview.accountName.isEmpty ? preview.name : preview.accountName,
                                      imagePath: nil, avatarURL: preview.avatarURL, size: 76)
                    Text(preview.name)
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text([preview.club, "č. \(preview.personNumber)"].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.center)
                    if !preview.accountName.isEmpty {
                        Text("Účet v Encore: \(preview.accountName)")
                            .font(.caption)
                            .foregroundColor(Color.gold300)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .homeCard()

                Text("Potvrď len vtedy, ak tohto človeka poznáš osobne a stojí pri tebe. Overením ručíš, že je to naozaj on.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if errorText == nil {
                ProgressView()
                    .tint(Color.gold400)
                    .frame(maxWidth: .infinity, minHeight: 160)
            }

            Spacer(minLength: 0)

            if let errorText {
                SheetBanner(text: errorText, isError: true)
            }
            if preview != nil {
                PrimarySheetButton(title: "Áno, poznám ho osobne", isLoading: isWorking, isEnabled: !isWorking) {
                    Task { await vouch() }
                }
            }
            Button(action: onDismiss) {
                Text(preview == nil ? "Zavrieť" : "Zrušiť")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.pressable)
        }
    }

    private func doneContent(_ preview: KSISVouchPreview) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 54, weight: .bold))
                .foregroundColor(Color.gold400)
                .symbolEffect(.bounce, value: isDone)
            Text("Overený")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
            Text("\(preview.name) je overený. Spojeniam sa teraz ukážu jeho výsledky, ak ich zdieľa.")
                .font(.subheadline)
                .foregroundColor(Color.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            PrimarySheetButton(title: "Hotovo", isLoading: false, isEnabled: true, action: onDismiss)
        }
    }

    private func load() async {
        do {
            preview = try await manager.peekVerifyCode(code)
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func vouch() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await manager.vouch(code)
            errorText = nil
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { isDone = true }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
