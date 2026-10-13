import SwiftUI

// MARK: - Focus order shared by the login screen and the sheets
enum AuthField: Hashable {
    case name, email, password, code, currentPassword, newPassword, confirmPassword
}

// MARK: - Shared field style (matches AuthSheetView inputs)
struct AuthFieldChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(.white)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.obsidian800, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.gold500.opacity(0.35), lineWidth: 1.5)
            )
    }
}

extension View {
    func authFieldChrome() -> some View { modifier(AuthFieldChrome()) }
}

struct SheetBanner: View {
    let text: String
    let isError: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text(text)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.footnote.weight(.medium))
        .foregroundColor(isError ? .latinRed : .gold400)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isError ? Color.latinRed : Color.gold500).opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke((isError ? Color.latinRed : Color.gold500).opacity(0.45), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

struct PrimarySheetButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        // Primary luxury button (BRAND_GUIDELINES §3): full champagne gold, black label.
        // Not ready yet = the same button, dimmed, so it still reads as the main action.
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView().tint(Color.obsidian900)
                } else {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundColor(Color.obsidian900)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 14, y: 5)
            .opacity(isEnabled || isLoading ? 1 : 0.4)
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled || isLoading)
        .animation(.easeOut(duration: 0.2), value: isEnabled)
    }
}

// MARK: - Password field with show / hide
struct PasswordField: View {
    let prompt: String
    @Binding var text: String
    var contentType: UITextContentType = .password
    var submitLabel: SubmitLabel = .done
    var focus: FocusState<AuthField?>.Binding
    var field: AuthField
    var onSubmit: () -> Void = {}

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isRevealed {
                    TextField("", text: $text, prompt: Text(prompt).foregroundColor(Color.gold300.opacity(0.45)))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("", text: $text, prompt: Text(prompt).foregroundColor(Color.gold300.opacity(0.45)))
                }
            }
            .textContentType(contentType)
            .focused(focus, equals: field)
            .submitLabel(submitLabel)
            .onSubmit(onSubmit)

            Button {
                isRevealed.toggle()
                focus.wrappedValue = field
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.55))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Skryť heslo" : "Zobraziť heslo")
        }
        .authFieldChrome()
    }
}

/// Four-segment strength bar. Guidance only, the real gate is `PasswordPolicy.issue`.
struct PasswordStrengthBar: View {
    let password: String

    private var level: Int { PasswordPolicy.strength(of: password) }
    private var color: Color {
        switch level {
        case 0...1: return .latinRed
        case 2: return .gold500
        default: return .syncEmerald
        }
    }
    private var label: String {
        switch level {
        case 0: return ""
        case 1: return "Slabé"
        case 2: return "Dobré"
        case 3: return "Silné"
        default: return "Veľmi silné"
        }
    }

    var body: some View {
        if !password.isEmpty {
            HStack(spacing: 6) {
                ForEach(1...4, id: \.self) { index in
                    Capsule()
                        .fill(index <= level ? color : Color.white.opacity(0.12))
                        .frame(height: 4)
                }
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 70, alignment: .trailing)
            }
            .animation(.easeOut(duration: 0.2), value: level)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sila hesla: \(label)")
        }
    }
}

// MARK: - Code field (6–10 digits, see EmailCodePolicy)
/// The code length is a server setting, so typing never submits by itself. A code pasted or filled in
/// from Mail (arriving at once) is submitted right away.
private struct CodeField: View {
    @Binding var code: String
    var focus: FocusState<AuthField?>.Binding
    var onComplete: () -> Void

    var body: some View {
        TextField("", text: $code, prompt: Text("Kód z e-mailu").foregroundColor(Color.gold300.opacity(0.5)))
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .multilineTextAlignment(.center)
            .font(.system(size: 26, weight: .bold, design: .monospaced))
            .tracking(code.isEmpty ? 0 : 4)
            .focused(focus, equals: .code)
            .authFieldChrome()
            .onChange(of: code) { oldValue, newValue in
                let digits = String(newValue.filter { $0.isASCII && $0.isNumber }.prefix(EmailCodePolicy.allowedLengths.upperBound))
                if digits != newValue { code = digits }
                let arrivedAtOnce = digits.count - oldValue.count > 1
                if arrivedAtOnce && EmailCodePolicy.isComplete(digits) { onComplete() }
            }
    }
}

// MARK: - Resend with cooldown
private struct ResendButton: View {
    let cooldown: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(cooldown > 0 ? "Poslať kód znova (\(cooldown) s)" : "Poslať kód znova")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(cooldown > 0 ? Color.white.opacity(0.35) : .gold400)
        }
        .disabled(cooldown > 0)
    }
}

// MARK: - Confirm e-mail after sign-up (code from the e-mail)
struct EmailCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthManager.shared

    @State private var code = ""
    @State private var isVerifying = false
    @State private var errorText: String?
    @State private var infoText: String?
    @State private var cooldown = 30
    @FocusState private var focus: AuthField?

    private var email: String { authManager.pendingConfirmationEmail ?? "" }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                    .contentShape(Rectangle())
                    .onTapGesture { focus = nil }

                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.gold400)
                        .padding(.top, 8)

                    Text("Potvrď e-mail")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(.gold400)

                    Text("Poslali sme kód na \(email). Zadaj ho sem. Skontroluj aj spam.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)

                    CodeField(code: $code, focus: $focus, onComplete: verify)

                    if let errorText { SheetBanner(text: errorText, isError: true) }
                    if let infoText { SheetBanner(text: infoText, isError: false) }

                    PrimarySheetButton(title: "Potvrdiť", isLoading: isVerifying, isEnabled: EmailCodePolicy.isComplete(code), action: verify)

                    HStack {
                        ResendButton(cooldown: cooldown, action: resend)
                        Spacer()
                        Button("Zmeniť e-mail") {
                            authManager.cancelPendingConfirmation()
                            dismiss()
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavrieť") { dismiss() }.foregroundColor(.gold400)
                }
            }
            .onAppear { focus = .code }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    if cooldown > 0 { cooldown -= 1 }
                }
            }
            .onChange(of: authManager.pendingConfirmationEmail) { _, newValue in
                if newValue == nil { dismiss() }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(isVerifying)
        .preferredColorScheme(.dark)
    }

    private func verify() {
        guard EmailCodePolicy.isComplete(code), !isVerifying else { return }
        errorText = nil
        infoText = nil
        isVerifying = true
        Task {
            let error = await authManager.verifySignupCode(code)
            isVerifying = false
            if let error {
                errorText = error
                code = ""
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func resend() {
        errorText = nil
        infoText = nil
        Task {
            if let error = await authManager.resendSignupCode() {
                errorText = error
            } else {
                infoText = "Nový kód je na ceste."
                cooldown = 60
            }
        }
    }
}

// MARK: - Forgot Password (from the login screen): e-mail, then the code from the e-mail
struct ForgotPasswordSheet: View {
    var prefillEmail: String = ""

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthManager.shared

    private enum Step { case email, code }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var code = ""
    @State private var isBusy = false
    @State private var errorText: String?
    @State private var infoText: String?
    @State private var cooldown = 0
    @FocusState private var focus: AuthField?

    private var canSend: Bool { EmailValidator.isValid(email) }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                    .contentShape(Rectangle())
                    .onTapGesture { focus = nil }

                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "key.horizontal.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.gold400)
                        .padding(.top, 8)

                    Text("Obnova hesla")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(.gold400)

                    switch step {
                    case .email:
                        Text("Zadaj e-mail, s ktorým si sa zaregistroval. Pošleme ti kód. Funguje na ktoromkoľvek zariadení.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)

                        TextField("", text: $email, prompt: Text("E-mailová adresa").foregroundColor(Color.gold300.opacity(0.45)))
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focus, equals: .email)
                            .submitLabel(.send)
                            .onSubmit { if canSend { sendCode() } }
                            .authFieldChrome()

                        if let errorText { SheetBanner(text: errorText, isError: true) }

                        PrimarySheetButton(title: "Poslať kód", isLoading: isBusy, isEnabled: canSend, action: sendCode)

                    case .code:
                        Text("Ak k adrese \(email.trimmingCharacters(in: .whitespacesAndNewlines)) existuje účet, kód je na ceste. Skontroluj aj spam. Kód platí 10 minút.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)

                        CodeField(code: $code, focus: $focus, onComplete: verify)

                        if let errorText { SheetBanner(text: errorText, isError: true) }
                        if let infoText { SheetBanner(text: infoText, isError: false) }

                        PrimarySheetButton(title: "Overiť kód", isLoading: isBusy, isEnabled: EmailCodePolicy.isComplete(code), action: verify)

                        HStack {
                            ResendButton(cooldown: cooldown, action: sendCode)
                            Spacer()
                            Button("Zmeniť e-mail") {
                                step = .email
                                code = ""
                                errorText = nil
                                infoText = nil
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavrieť") { dismiss() }.foregroundColor(.gold400)
                }
            }
            .onAppear {
                if email.isEmpty { email = prefillEmail }
                focus = .email
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    if cooldown > 0 { cooldown -= 1 }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isBusy)
        .preferredColorScheme(.dark)
    }

    private func sendCode() {
        guard !isBusy else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        errorText = nil
        infoText = nil
        isBusy = true
        Task {
            let error = await authManager.sendPasswordReset(email: email)
            isBusy = false
            if let error {
                errorText = error
            } else {
                if step == .code { infoText = "Nový kód je na ceste." }
                step = .code
                cooldown = 60
                focus = .code
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func verify() {
        guard EmailCodePolicy.isComplete(code), !isBusy else { return }
        errorText = nil
        infoText = nil
        isBusy = true
        Task {
            let error = await authManager.verifyRecoveryCode(email: email, code: code)
            isBusy = false
            if let error {
                errorText = error
                code = ""
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            } else {
                // The app now opens the "new password" sheet over the signed-in app.
                dismiss()
            }
        }
    }
}

// MARK: - Change / Set Password
/// `.change`   – signed-in e-mail user changes the password from Profile (current password required).
/// `.recovery` – user proved the e-mail (code or link) and chooses a new password.
struct PasswordUpdateSheet: View {
    enum Mode { case change, recovery }

    let mode: Mode

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authManager = AuthManager.shared

    @State private var current = ""
    @State private var newPassword = ""
    @State private var confirm = ""
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var didSucceed = false
    @FocusState private var focus: AuthField?

    private var mismatch: Bool { !confirm.isEmpty && confirm != newPassword }
    private var policyIssue: String? {
        newPassword.isEmpty ? nil : PasswordPolicy.issue(for: newPassword, email: authManager.userEmail)
    }

    private var canSubmit: Bool {
        !newPassword.isEmpty && PasswordPolicy.issue(for: newPassword, email: authManager.userEmail) == nil
            && newPassword == confirm && (mode == .recovery || !current.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                    .contentShape(Rectangle())
                    .onTapGesture { focus = nil }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Image(systemName: "lock.rotation")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.gold400)
                            .padding(.top, 8)

                        Text(mode == .recovery ? "Nové heslo" : "Zmena hesla")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(.gold400)

                        Text(mode == .recovery
                             ? "Kód je overený. Zvoľ si nové heslo pre svoj účet."
                             : "Pre bezpečnosť najprv zadaj súčasné heslo.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: 14) {
                            if mode == .change {
                                PasswordField(
                                    prompt: "Súčasné heslo", text: $current, contentType: .password,
                                    submitLabel: .next, focus: $focus, field: .currentPassword,
                                    onSubmit: { focus = .newPassword }
                                )
                            }

                            PasswordField(
                                prompt: "Nové heslo (min. \(PasswordPolicy.minLength) znakov)", text: $newPassword,
                                contentType: .newPassword, submitLabel: .next, focus: $focus, field: .newPassword,
                                onSubmit: { focus = .confirmPassword }
                            )
                            PasswordStrengthBar(password: newPassword)

                            PasswordField(
                                prompt: "Zopakuj nové heslo", text: $confirm, contentType: .newPassword,
                                submitLabel: .done, focus: $focus, field: .confirmPassword,
                                onSubmit: { if canSubmit { save() } }
                            )
                        }
                        .disabled(didSucceed)

                        if let policyIssue {
                            Text(policyIssue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.latinRed)
                        } else if mismatch {
                            Text("Heslá sa nezhodujú.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.latinRed)
                        }

                        if let errorText { SheetBanner(text: errorText, isError: true) }

                        if didSucceed {
                            SheetBanner(text: "Heslo bolo úspešne zmenené. Na ostatných zariadeniach si odhlásený.", isError: false)
                        } else {
                            PrimarySheetButton(
                                title: "Uložiť nové heslo",
                                isLoading: isSaving,
                                isEnabled: canSubmit
                            ) { save() }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(mode == .recovery ? "Preskočiť" : "Zavrieť") { dismiss() }
                        .foregroundColor(.gold400)
                        .disabled(isSaving)
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(isSaving)
        .preferredColorScheme(.dark)
    }

    private func save() {
        guard canSubmit, !isSaving else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        errorText = nil
        isSaving = true
        Task {
            let error: String?
            switch mode {
            case .change:
                error = await authManager.changePassword(current: current, new: newPassword)
            case .recovery:
                error = await authManager.setNewPassword(newPassword)
            }
            isSaving = false
            if let error {
                errorText = error
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            } else {
                didSucceed = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                try? await Task.sleep(for: .milliseconds(1300))
                dismiss()
            }
        }
    }
}

#Preview("PasswordUpdateSheet") {
    PasswordUpdateSheet(mode: .change)
}

#Preview("ForgotPasswordSheet") {
    ForgotPasswordSheet(prefillEmail: "meno@domena.sk")
}

#Preview("EmailCodeSheet") {
    EmailCodeSheet()
}
