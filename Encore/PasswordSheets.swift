import SwiftUI

// MARK: - Focus order shared by the login screen and the sheets
enum AuthField: Hashable {
    case name, email, password, code, currentPassword, newPassword, confirmPassword
}

// MARK: - Shared field style (BRAND_GUIDELINES §1A)
/// Glass field; with `isFocused` the edge turns gold and a gold line sweeps around it.
struct AuthFieldChrome: ViewModifier {
    var isFocused = false

    @State private var sweepTrigger = 0

    func body(content: Content) -> some View {
        content
            .foregroundColor(.white)
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isFocused ? Color.gold400.opacity(0.5) : Color.white.opacity(0.10), lineWidth: 1)
            )
            .overlay { FieldEdgeSweep(trigger: sweepTrigger) }
            .onChange(of: isFocused) { _, focused in
                if focused { sweepTrigger += 1 }
            }
            .animation(.easeOut(duration: 0.2), value: isFocused)
    }
}

extension View {
    func authFieldChrome(isFocused: Bool = false) -> some View { modifier(AuthFieldChrome(isFocused: isFocused)) }
}

struct SheetBanner: View {
    let text: String
    let isError: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .symbolEffect(.bounce, value: text)
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
        .transition(.opacity.combined(with: .move(edge: .top)))
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

// MARK: - Shake on a wrong answer
/// Moves the view sideways three times as `shakes` grows by one. Callers skip it with Reduce Motion.
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(shakes * .pi * 6), y: 0))
    }
}

extension View {
    /// Shakes the view once each time `count` grows (nothing with Reduce Motion).
    func shake(_ count: Int, reduceMotion: Bool) -> some View {
        modifier(ShakeEffect(shakes: reduceMotion ? 0 : CGFloat(count)))
            .animation(reduceMotion ? nil : .linear(duration: 0.45), value: count)
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
                    TextField("", text: $text, prompt: Text(prompt).foregroundColor(.white.opacity(0.5)))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("", text: $text, prompt: Text(prompt).foregroundColor(.white.opacity(0.5)))
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
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(scale: 0.85))
            .accessibilityLabel(isRevealed ? "Skryť heslo" : "Zobraziť heslo")
        }
        .authFieldChrome(isFocused: focus.wrappedValue == field)
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
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(color)
                    .frame(width: 76, alignment: .trailing)
                    .contentTransition(.opacity)
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: level)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sila hesla: \(label)")
            .transition(.opacity)
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
        TextField("", text: $code, prompt: Text("Kód z e-mailu").foregroundColor(.white.opacity(0.5)))
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .multilineTextAlignment(.center)
            .font(.system(size: 26, weight: .bold, design: .monospaced))
            .tracking(code.isEmpty ? 0 : 4)
            .focused(focus, equals: .code)
            .authFieldChrome(isFocused: focus.wrappedValue == .code)
            .accessibilityLabel("Kód z e-mailu")
            .onChange(of: code) { oldValue, newValue in
                let digits = String(newValue.filter { $0.isASCII && $0.isNumber }.prefix(EmailCodePolicy.allowedLengths.upperBound))
                if digits != newValue { code = digits }
                let arrivedAtOnce = digits.count - oldValue.count > 1
                if arrivedAtOnce && EmailCodePolicy.isComplete(digits) { onComplete() }
            }
    }
}

// MARK: - Resend with cooldown
/// The server lets a new e-mail go out after 60 s; the countdown matches it.
private struct ResendButton: View {
    let cooldown: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(cooldown > 0 ? "Poslať kód znova (\(cooldown) s)" : "Poslať kód znova")
                .font(.footnote.weight(.semibold))
                .foregroundColor(cooldown > 0 ? .white.opacity(0.45) : .gold400)
                .contentTransition(.numericText(countsDown: true))
                .frame(minHeight: 44)
        }
        .buttonStyle(.pressable)
        .disabled(cooldown > 0)
    }
}

/// A plain text action under a sheet's main button ("Zmeniť e-mail").
private struct SheetTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.footnote.weight(.medium))
            .foregroundColor(.white.opacity(0.7))
            .frame(minHeight: 44)
            .buttonStyle(.pressable)
    }
}

// MARK: - Sheet frame
/// The frame of every auth sheet: velvet, a glass close button, an icon, a gold title, a short explanation.
private struct AuthSheetScaffold<Content: View>: View {
    let systemImage: String
    let title: String
    let message: String
    var closeLabel = "Zavrieť"
    var isBusy = false
    var onTapBackground: () -> Void = {}
    @ViewBuilder let content: Content

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            EllegancePageBackground()
                .contentShape(Rectangle())
                .onTapGesture(perform: onTapBackground)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: systemImage)
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.gold400)
                        .frame(width: 56, height: 56)
                        .background(Color.gold500.opacity(0.14), in: Circle())
                        .overlay(Circle().stroke(Color.gold400.opacity(0.35), lineWidth: 1))
                        .symbolEffect(.bounce, value: title)
                        .accessibilityHidden(true)

                    Text(title)
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundColor(.gold400)
                        .accessibilityAddTraits(.isHeader)

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)

                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: title)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    LiquidGlassCircleButton(icon: "xmark", label: closeLabel, size: 40) { dismiss() }
                        .disabled(isBusy)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 4)
            }
        }
        .environment(\.locale, Locale(identifier: "sk"))
        .interactiveDismissDisabled(isBusy)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Confirm e-mail after sign-up (code from the e-mail)
struct EmailCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var authManager = AuthManager.shared

    @State private var code = ""
    @State private var isVerifying = false
    @State private var errorText: String?
    @State private var infoText: String?
    @State private var cooldown = 60
    @State private var shakes = 0
    @State private var successTick = 0
    @FocusState private var focus: AuthField?

    private var email: String { authManager.pendingConfirmationEmail ?? "" }

    var body: some View {
        AuthSheetScaffold(
            systemImage: "envelope.badge.fill",
            title: "Potvrď e-mail",
            message: "Poslali sme kód na \(email). Zadaj ho sem. Skontroluj aj spam.",
            isBusy: isVerifying,
            onTapBackground: { focus = nil }
        ) {
            CodeField(code: $code, focus: $focus, onComplete: verify)
                .shake(shakes, reduceMotion: reduceMotion)

            if let errorText { SheetBanner(text: errorText, isError: true) }
            if let infoText { SheetBanner(text: infoText, isError: false) }

            PrimarySheetButton(title: "Potvrdiť", isLoading: isVerifying, isEnabled: EmailCodePolicy.isComplete(code), action: verify)

            HStack {
                ResendButton(cooldown: cooldown, action: resend)
                Spacer()
                SheetTextButton(title: "Zmeniť e-mail") {
                    authManager.cancelPendingConfirmation()
                    dismiss()
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: errorText)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: infoText)
        .sensoryFeedback(.error, trigger: shakes)
        .sensoryFeedback(.success, trigger: successTick)
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
        .presentationDetents([.large])
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
                shakes += 1
            } else {
                successTick += 1
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var authManager = AuthManager.shared

    private enum Step { case email, code }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var code = ""
    @State private var isBusy = false
    @State private var errorText: String?
    @State private var infoText: String?
    @State private var cooldown = 0
    @State private var shakes = 0
    @State private var sentTick = 0
    @FocusState private var focus: AuthField?

    private var canSend: Bool { EmailValidator.isValid(email) }
    private var cleanEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        AuthSheetScaffold(
            systemImage: step == .email ? "key.horizontal.fill" : "envelope.open.fill",
            title: "Obnova hesla",
            message: step == .email
                ? "Zadaj e-mail, s ktorým si sa zaregistroval. Pošleme ti kód. Funguje na ktoromkoľvek zariadení."
                : "Ak k adrese \(cleanEmail) existuje účet, kód je na ceste. Skontroluj aj spam. Kód platí 10 minút.",
            isBusy: isBusy,
            onTapBackground: { focus = nil }
        ) {
            switch step {
            case .email:
                TextField("", text: $email, prompt: Text("E-mailová adresa").foregroundColor(.white.opacity(0.5)))
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.send)
                    .onSubmit { if canSend { sendCode() } }
                    .authFieldChrome(isFocused: focus == .email)
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))

                if let errorText { SheetBanner(text: errorText, isError: true) }

                PrimarySheetButton(title: "Poslať kód", isLoading: isBusy, isEnabled: canSend, action: sendCode)

            case .code:
                CodeField(code: $code, focus: $focus, onComplete: verify)
                    .shake(shakes, reduceMotion: reduceMotion)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))

                if let errorText { SheetBanner(text: errorText, isError: true) }
                if let infoText { SheetBanner(text: infoText, isError: false) }

                PrimarySheetButton(title: "Overiť kód", isLoading: isBusy, isEnabled: EmailCodePolicy.isComplete(code), action: verify)

                HStack {
                    ResendButton(cooldown: cooldown, action: sendCode)
                    Spacer()
                    SheetTextButton(title: "Zmeniť e-mail") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            step = .email
                            code = ""
                            errorText = nil
                            infoText = nil
                        }
                        focus = .email
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: errorText)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: infoText)
        .sensoryFeedback(.error, trigger: shakes)
        .sensoryFeedback(.success, trigger: sentTick)
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
        .presentationDetents([.large])
    }

    private func sendCode() {
        guard !isBusy else { return }
        errorText = nil
        infoText = nil
        isBusy = true
        Task {
            let error = await authManager.sendPasswordReset(email: email)
            isBusy = false
            if let error {
                errorText = error
                shakes += 1
            } else {
                if step == .code { infoText = "Nový kód je na ceste." }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step = .code }
                cooldown = 60
                focus = .code
                sentTick += 1
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
                shakes += 1
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var authManager = AuthManager.shared

    @State private var current = ""
    @State private var newPassword = ""
    @State private var confirm = ""
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var didSucceed = false
    @State private var shakes = 0
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
        AuthSheetScaffold(
            systemImage: didSucceed ? "checkmark.seal.fill" : "lock.rotation",
            title: mode == .recovery ? "Nové heslo" : "Zmena hesla",
            message: mode == .recovery
                ? "Kód je overený. Zvoľ si nové heslo pre svoj účet. Ak to teraz zavrieš, ostaneš prihlásený a heslo si zmeníš neskôr v Profile."
                : "Pre bezpečnosť najprv zadaj súčasné heslo.",
            closeLabel: mode == .recovery ? "Teraz nie" : "Zavrieť",
            isBusy: isSaving,
            onTapBackground: { focus = nil }
        ) {
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
            .shake(shakes, reduceMotion: reduceMotion)

            if let policyIssue {
                Text(policyIssue)
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.latinRed)
                    .transition(.opacity)
            } else if mismatch {
                Text("Heslá sa nezhodujú.")
                    .font(.footnote.weight(.medium))
                    .foregroundColor(.latinRed)
                    .transition(.opacity)
            }

            if let errorText { SheetBanner(text: errorText, isError: true) }

            if didSucceed {
                SheetBanner(text: "Heslo je zmenené. Na ostatných zariadeniach si odhlásený.", isError: false)
            } else {
                PrimarySheetButton(title: "Uložiť nové heslo", isLoading: isSaving, isEnabled: canSubmit) { save() }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: errorText)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: didSucceed)
        .animation(.easeOut(duration: 0.2), value: policyIssue)
        .animation(.easeOut(duration: 0.2), value: mismatch)
        .sensoryFeedback(.error, trigger: shakes)
        .sensoryFeedback(.success, trigger: didSucceed)
        .presentationDetents([.large])
    }

    private func save() {
        guard canSubmit, !isSaving else { return }
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
                shakes += 1
            } else {
                didSucceed = true
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
