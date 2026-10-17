import Foundation
import SwiftUI
import Combine
import PassKit
import Supabase
import Auth
import OSLog

// MARK: - Apple Wallet Pass Manager & PassKit Bridge
@MainActor
final class AppleWalletPassManager: NSObject, ObservableObject {
    static let shared = AppleWalletPassManager()
    
    @Published var isLoadingPass = false
    @Published var errorMessage: String? = nil
    @Published var passAddedSuccessfully = false
    @Published var isPassInWallet = false
    @Published var showErrorAlert = false
    @Published var alertTitle = "Apple Peňaženka"
    @Published var alertMessage = ""
    
    private let passTypeIdentifier = "pass.com.jakub.encore"

    /// The web signs passes with the Pass Type ID certificate (Vercel, APPLE_PASS_* variables, 17. 10. 2026).
    /// Set to false again if signing ever stops: a button that only shows an error is rejected (App Review 2.1).
    static let canIssuePasses = true

    private override init() {
        super.init()
        checkWalletStatus()
    }
    
    var isPassLibraryAvailable: Bool {
        PKPassLibrary.isPassLibraryAvailable()
    }
    
    func checkWalletStatus() {
        guard isPassLibraryAvailable else {
            isPassInWallet = false
            return
        }
        
        let library = PKPassLibrary()
        let matchingPasses = library.passes().filter {
            $0.passTypeIdentifier == self.passTypeIdentifier || $0.passTypeIdentifier.contains("encore")
        }
        self.isPassInWallet = !matchingPasses.isEmpty
    }
    
    /// Requests the .pkpass bundle from the Encore server endpoint and presents the native iOS Apple Wallet dialog
    func addCardToAppleWallet(userId: String, name: String, club: String) async {
        guard isPassLibraryAvailable else {
            self.errorMessage = "Apple Peňaženka nie je na tomto zariadení dostupná."
            self.alertTitle = "Apple Peňaženka nie je dostupná"
            self.alertMessage = "Tvoje zariadenie nepodporuje Apple Wallet."
            self.showErrorAlert = true
            HapticFeedback.error()
            return
        }
        
        isLoadingPass = true
        errorMessage = nil
        
        do {
            guard let url = AppWebsite.url("/api/wallet/pass") else {
                throw URLError(.badURL)
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 20.0
            // The server signs the pass only for the signed-in dancer.
            if let session = try? await SupabaseConfig.client.auth.session {
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                // The server says why (JSON "error" and "message"); show it instead of a generic text.
                let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
                let code = json?["error"] as? String ?? "http_\(status)"
                Logger.general.error("Wallet pass refused: \(status, privacy: .public) \(code, privacy: .public)")
                showProblem(Self.message(for: status, code: code, serverMessage: json?["message"] as? String))
                isLoadingPass = false
                return
            }

            do {
                let pass = try PKPass(data: data)
                presentPassViewController(pass: pass)
            } catch {
                Logger.general.error("Wallet pass rejected by iOS: \(error.localizedDescription, privacy: .public)")
                showProblem("Server kartu vytvoril, ale iOS ju neprijal (podpis alebo obrázky karty). Chyba: \(error.localizedDescription)")
            }
        } catch {
            Logger.general.error("Wallet pass fetch failed: \(error.localizedDescription, privacy: .public)")
            showProblem("Kartu sa nepodarilo stiahnuť. Skontroluj pripojenie a skús to znova.")
        }

        isLoadingPass = false
    }
    
    private func showProblem(_ message: String) {
        alertTitle = "Kartu sa nepodarilo pridať"
        alertMessage = message
        errorMessage = message
        showErrorAlert = true
        HapticFeedback.warning()
    }

    /// Readable reasons for what the pass endpoint answers.
    static func message(for status: Int, code: String, serverMessage: String?) -> String {
        switch (status, code) {
        case (401, _):
            return "Server ťa neoveril (\(code)). Odhlás sa a prihlás znova, potom to skús ešte raz."
        case (503, _):
            return "Na serveri ešte nie sú certifikáty pre Apple Peňaženku."
        default:
            let reason = serverMessage.map { " \($0)" } ?? ""
            return "Server kartu nevytvoril (\(status), \(code)).\(reason)"
        }
    }

    /// Shown over whatever is on top (the card screen can sit in a sheet or a navigation stack).
    private func presentPassViewController(pass: PKPass) {
        guard let top = UIViewController.topMost(), let passVC = PKAddPassesViewController(pass: pass) else {
            showProblem("Apple Peňaženku sa nepodarilo otvoriť.")
            return
        }
        passVC.delegate = self
        top.present(passVC, animated: true)
    }
}

// MARK: - PKAddPassesViewControllerDelegate
extension AppleWalletPassManager: PKAddPassesViewControllerDelegate {
    nonisolated func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
        Task { @MainActor in
            controller.dismiss(animated: true) {
                self.passAddedSuccessfully = true
                self.checkWalletStatus()
                HapticFeedback.success()
            }
        }
    }
}

// MARK: - Native PKAddPassButton SwiftUI Wrapper
struct AddToAppleWalletButton: UIViewRepresentable {
    var style: PKAddPassButtonStyle = .black
    var action: () -> Void
    
    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: style)
        button.addTarget(context.coordinator, action: #selector(Coordinator.buttonTapped), for: .touchUpInside)
        return button
    }
    
    func updateUIView(_ uiView: PKAddPassButton, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) {
            self.action = action
        }
        @objc func buttonTapped() {
            action()
        }
    }
}
