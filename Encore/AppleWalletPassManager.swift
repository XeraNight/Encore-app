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
    @Published var fallbackURL: URL? = nil
    
    private let passTypeIdentifier = "pass.com.jakub.encore"

    /// Off until the Developer account signs passes (docs/V1_LAUNCH_CHECKLIST.md). Until then the button
    /// would only show an error, which App Review rejects (2.1), so the card hides it.
    static let canIssuePasses = false

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
        fallbackURL = URL(string: FriendManager.shared.buildMemberCardURL())
        
        do {
            guard let url = AppWebsite.url("/api/wallet/pass") else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 12.0
            
            // Attach Supabase access token for secure user verification
            if let session = try? await SupabaseConfig.client.auth.session {
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            }
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            if httpResponse.statusCode == 200 {
                let pass = try PKPass(data: data)
                presentPassViewController(pass: pass)
            } else if httpResponse.statusCode == 503 {
                // Certificates not uploaded to Vercel yet
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let serverMsg = json["message"] as? String {
                    self.alertTitle = "Apple Peňaženka – Nastavenie Certifikátov"
                    self.alertMessage = serverMsg
                } else {
                    self.alertTitle = "Apple Peňaženka – Certifikát"
                    self.alertMessage = "Apple PassKit certifikáty zatiaľ nie sú nahrané na Vercel serveri."
                }
                self.showErrorAlert = true
                HapticFeedback.warning()
            } else {
                throw URLError(.badServerResponse)
            }
        } catch {
            Logger.general.error("Wallet pass fetch failed: \(error.localizedDescription, privacy: .public)")
            self.errorMessage = "Digitálny lístok vyžaduje Apple PassKit podpisový certifikát."
            self.alertTitle = "Apple Peňaženka – Stav Nastavenia"
            self.alertMessage = "Pridanie preukazu do systémovej Apple Peňaženky vyžaduje podpísaný .pkpass súbor s Apple Developer certifikátom. Tvoja Encore karta funguje s plnou platnosťou priamo v aplikácii cez osobný QR kód."
            self.showErrorAlert = true
            HapticFeedback.warning()
        }
        
        isLoadingPass = false
    }
    
    private func presentPassViewController(pass: PKPass) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let passVC = PKAddPassesViewController(pass: pass)
        passVC?.delegate = self
        if let passVC = passVC {
            rootVC.present(passVC, animated: true)
        }
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
