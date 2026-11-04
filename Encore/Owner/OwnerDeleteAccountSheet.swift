import SwiftUI

// MARK: - Owner: delete someone's account
/// The owner deletes an account for good (BRAND_GUIDELINES §1A). The server decides: it checks the owner, the PIN kept
/// only in Supabase (`OWNER_DELETE_PIN`) and the typed e-mail, and logs every attempt
/// (`supabase/functions/owner-delete-account`). Face ID here only keeps a borrowed, unlocked iPhone from trying.
struct OwnerDeleteAccountSheet: View {
    let user: AdminUserSearchItem
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focus: AuthField?
    @State private var email = ""
    @State private var pin = ""
    @State private var isDeleting = false
    @State private var errorText: String?
    @State private var shakes = 0

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isReady: Bool { !trimmedEmail.isEmpty && pin.count >= 6 }

    private struct Request: Encodable {
        let targetUserId: UUID
        let confirmEmail: String
        let pin: String
    }

    private struct Reply: Decodable {
        let ok: Bool
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        warning

                        HomeSectionHeader(title: "POTVRDENIE", systemImage: "checkmark.shield.fill")
                        TextField("", text: $email,
                                  prompt: Text(user.email ?? "E-mail účtu").foregroundColor(Color.textPlaceholder))
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focus, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focus = .password }
                            .authFieldChrome(isFocused: focus == .email)
                        PasswordField(prompt: "PIN na mazanie účtov", text: $pin, focus: $focus, field: .password,
                                      onSubmit: delete)

                        if let errorText {
                            SheetBanner(text: errorText, isError: true)
                        }

                        Button(role: .destructive, action: delete) {
                            HStack {
                                if isDeleting {
                                    ProgressView().tint(.white)
                                } else {
                                    Label("Zmazať natrvalo", systemImage: "trash.fill")
                                        .font(.headline.weight(.bold))
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.latinRed.opacity(isReady ? 0.9 : 0.35),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.pressable(scale: 0.97))
                        .disabled(!isReady || isDeleting)
                        .shake(shakes, reduceMotion: reduceMotion)
                        .animation(.easeOut(duration: 0.2), value: isReady)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: errorText)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Zmazať účet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušiť") { dismiss() }
                        .disabled(isDeleting)
                }
            }
            .interactiveDismissDisabled(isDeleting)
            .sensoryFeedback(.error, trigger: shakes)
        }
        .preferredColorScheme(.dark)
    }

    private var warning: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(user.name)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            Text("Zmažú sa zostavy, poznámky, výsledky, zdieľané videá aj prihlásenie. Vrátiť sa to nedá.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Text("Prepíš e-mail účtu a zadaj PIN, ktorý máš v Supabase.")
                .font(.footnote)
                .foregroundColor(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 20)
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.latinRed.opacity(0.45), lineWidth: 1))
    }

    private func delete() {
        guard isReady, !isDeleting else { return }
        focus = nil
        errorText = nil
        isDeleting = true
        Task {
            defer { isDeleting = false }
            guard await AuthManager.shared.confirmDeviceOwner(reason: "Potvrď zmazanie účtu \(user.name).") else { return }
            do {
                let _: Reply = try await EdgeFunctionClient.call(
                    "owner-delete-account",
                    Request(targetUserId: user.id, confirmEmail: trimmedEmail, pin: pin))
                onDeleted()
                dismiss()
            } catch EdgeFunctionClient.Failure.server(_, let message) {
                pin = ""
                errorText = message ?? "Účet sa nepodarilo zmazať."
                shakes += 1
            } catch {
                errorText = "Bez pripojenia sa účet zmazať nedá."
                shakes += 1
            }
        }
    }
}
