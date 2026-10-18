import Foundation
import SwiftUI
import Combine
import PassKit
import Supabase
import Auth
import OSLog

// MARK: - Apple Wallet Pass Manager & PassKit Bridge
/// The member card in Apple Wallet. The app sees its own card thanks to the pass type in
/// Encore.entitlements, so it knows when the card is added or removed, opens it in Wallet and swaps it
/// for a fresh copy when the QR code changes (`replacePass`, no dialog).
@MainActor
final class AppleWalletPassManager: NSObject, ObservableObject {
    static let shared = AppleWalletPassManager()

    @Published var isLoadingPass = false
    @Published private(set) var isPassInWallet = false
    @Published var showErrorAlert = false
    @Published var alertTitle = "Apple Peňaženka"
    @Published var alertMessage = ""

    private let passTypeIdentifier = "pass.com.jakub.encore"
    private var cancellables = Set<AnyCancellable>()

    /// The web signs passes with the Pass Type ID certificate (Vercel, APPLE_PASS_* variables, 17. 10. 2026).
    /// Set to false again if signing ever stops: a button that only shows an error is rejected (App Review 2.1).
    static let canIssuePasses = true

    private override init() {
        super.init()
        checkWalletStatus()
        // Removing the card in Wallet shows "Pridať" again, also when it happened while Encore was closed.
        NotificationCenter.default.publisher(for: Notification.Name(PKPassLibraryNotificationName.PKPassLibraryDidChange.rawValue))
            .merge(with: NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.checkWalletStatus() }
            .store(in: &cancellables)
    }

    var isPassLibraryAvailable: Bool {
        PKPassLibrary.isPassLibraryAvailable()
    }

    /// Encore's card in Wallet, if the dancer has it.
    private var walletPass: PKPass? {
        guard isPassLibraryAvailable else { return nil }
        return PKPassLibrary().passes().first { $0.passTypeIdentifier == passTypeIdentifier }
    }

    func checkWalletStatus() {
        isPassInWallet = walletPass != nil
    }

    /// Requests the .pkpass bundle from the Encore server endpoint and presents the native iOS Apple Wallet dialog
    func addCardToAppleWallet() async {
        guard isPassLibraryAvailable else {
            alertTitle = "Apple Peňaženka nie je dostupná"
            alertMessage = "Tvoje zariadenie nepodporuje Apple Wallet."
            showErrorAlert = true
            HapticFeedback.error()
            return
        }
        guard let pass = await downloadPass(reportProblems: true) else { return }
        presentPassViewController(pass: pass)
    }

    /// Shows the card in the Wallet app.
    func openInWallet() {
        guard let url = walletPass?.passURL else { return }
        UIApplication.shared.open(url)
    }

    /// Puts a fresh copy of the card into Wallet without a dialog (the same card with a new QR code or look).
    /// Quiet when the app does it on its own after a new invite token; the dancer's own tap shows problems.
    func updatePassInWallet(userInitiated: Bool = false) async {
        guard isPassInWallet, !isLoadingPass else { return }
        guard let pass = await downloadPass(reportProblems: userInitiated) else { return }
        if PKPassLibrary().replacePass(with: pass) {
            if userInitiated { HapticFeedback.success() }
        } else {
            Logger.general.error("Wallet pass replace refused")
            if userInitiated {
                showProblem("Kartu v Peňaženke sa nepodarilo aktualizovať. Vymaž ju v Peňaženke a pridaj znova.")
            }
        }
    }

    /// A deleted account's card must not stay in Wallet with a QR code that leads nowhere.
    func removePassFromWallet() {
        guard let pass = walletPass else { return }
        PKPassLibrary().removePass(pass)
        isPassInWallet = false
    }

    /// The signed card for the signed-in dancer, or nil (with a message when `reportProblems`).
    private func downloadPass(reportProblems: Bool) async -> PKPass? {
        isLoadingPass = true
        defer { isLoadingPass = false }
        // The card's QR code is the current invite token, the same as on the card in Encore.
        await FriendManager.shared.fetchOrGenerateInviteToken()

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
                if reportProblems {
                    showProblem(Self.message(for: status, code: code, serverMessage: json?["message"] as? String))
                }
                return nil
            }

            do {
                return try PKPass(data: data)
            } catch {
                Logger.general.error("Wallet pass rejected by iOS: \(error.localizedDescription, privacy: .public)")
                if reportProblems {
                    showProblem("Server kartu vytvoril, ale iOS ju neprijal (podpis alebo obrázky karty). Chyba: \(error.localizedDescription)")
                }
                return nil
            }
        } catch {
            Logger.general.error("Wallet pass fetch failed: \(error.localizedDescription, privacy: .public)")
            if reportProblems {
                showProblem("Kartu sa nepodarilo stiahnuť. Skontroluj pripojenie a skús to znova.")
            }
            return nil
        }
    }

    private func showProblem(_ message: String) {
        alertTitle = "Kartu sa nepodarilo pridať"
        alertMessage = message
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
                self.checkWalletStatus()
                if self.isPassInWallet { HapticFeedback.success() }
            }
        }
    }
}
