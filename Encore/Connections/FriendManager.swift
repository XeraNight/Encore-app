import Foundation
import SwiftUI
import OSLog
import Combine
import Supabase

// MARK: - Friend & Community Manager (Supabase RPC, Universal Links & Deferred Deep Linking)
@MainActor
final class FriendManager: ObservableObject {
    static let shared = FriendManager()
    
    @Published var incomingInvite: FriendInvitePayload? = nil
    @Published var showInviteSheet: Bool = false
    @Published var showDeferredInvitePrompt: Bool = false
    @Published var isProcessingInvite: Bool = false
    @Published var isRefreshingToken: Bool = false
    @Published var inviteErrorMessage: String? = nil
    @Published var activeInviteToken: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Check pending invites and refresh the own invite token when the active user changes
        UserProfileStore.shared.$currentName
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.checkPendingInviteAfterLogin()
                Task {
                    await self?.fetchOrGenerateInviteToken()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Token Management
    /// Reuses the stored invite token while it is still valid for at least a day. A new one (which
    /// revokes the old one on the server) is only made when none exists, it is about to expire,
    /// or the user explicitly asks for a new QR code (`force`).
    func fetchOrGenerateInviteToken(force: Bool = false) async {
        guard AuthManager.shared.isAuthenticated else { return }
        let client = SupabaseConfig.client
        let uid = UserProfileStore.shared.activeUserId
        let defaults = UserDefaults.standard
        let tokenKey = "encore_active_invite_token_\(uid)"
        let expiryKey = "encore_active_invite_token_exp_\(uid)"
        
        if let cached = defaults.string(forKey: tokenKey), !cached.isEmpty {
            self.activeInviteToken = cached
            let expiry = defaults.double(forKey: expiryKey)
            let hasDayLeft = expiry > Date().addingTimeInterval(24 * 60 * 60).timeIntervalSince1970
            if !force && hasDayLeft { return }
        }
        
        do {
            struct TokenParams: Encodable {
                let p_expires_in_days: Int
            }
            let token: String = try await client.rpc(
                "create_friend_invite_token",
                params: TokenParams(p_expires_in_days: 7)
            ).execute().value
            
            self.activeInviteToken = token
            defaults.set(token, forKey: tokenKey)
            defaults.set(Date().addingTimeInterval(7 * 24 * 60 * 60).timeIntervalSince1970, forKey: expiryKey)
            // The old token no longer works, so the card in Apple Wallet gets the new QR code too.
            await AppleWalletPassManager.shared.updatePassInWallet()
        } catch {
            // No made-up token: the server would not know it. The card falls back to the dancer code link.
            Logger.general.notice("Invite token generation failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func refreshInviteToken() async {
        isRefreshingToken = true
        HapticFeedback.light()
        await fetchOrGenerateInviteToken(force: true)
        isRefreshingToken = false
        HapticFeedback.success()
    }
    
    // MARK: - Member Card Smart URL Generator
    func buildMemberCardURL() -> String {
        if !activeInviteToken.isEmpty {
            return "https://\(AppWebsite.host)/add?t=\(activeInviteToken)"
        }
        let code = UserProfileStore.shared.dancerCode
        if !code.isEmpty {
            return "https://\(AppWebsite.host)/add/\(code)"
        }
        return "https://\(AppWebsite.host)/add"
    }
    
    // MARK: - Universal Link / Deep Link Handler
    /// Accepts only an opaque invite token (`/add?t=tok_…`, `encore://add?t=tok_…`) or a dancer code
    /// (`/add/DNC-…`, `encore://add?code=DNC-…`). The name shown is always loaded from the server, never
    /// taken from the link, so a link cannot pretend to be someone else.
    @discardableResult
    func handleIncomingURL(_ url: URL) -> Bool {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let query = components?.queryItems ?? []
        let isEncoreLink = url.scheme == "encore" || AppWebsite.isOwn(url)
        guard isEncoreLink else { return false }

        if let token = query.first(where: { $0.name == "t" || $0.name == "token" })?.value, !token.isEmpty {
            return processInviteToken(token)
        }
        if let code = query.first(where: { $0.name == "code" })?.value, !code.isEmpty {
            return processInviteCode(code)
        }
        if url.path.hasPrefix("/add/") {
            let last = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            return last.hasPrefix("tok_") ? processInviteToken(last) : processInviteCode(last)
        }
        return false
    }
    
    // MARK: - Process Token Invite (Opaque Token)
    @discardableResult
    func processInviteToken(_ token: String) -> Bool {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else { return false }
        
        if !AuthManager.shared.isAuthenticated {
            UserDefaults.standard.set(cleanToken, forKey: "encore_pending_invite_token")
            return true
        }
        
        isProcessingInvite = true
        inviteErrorMessage = nil
        
        Task {
            await fetchAndPresentTokenInvite(token: cleanToken)
        }
        return true
    }
    
    // MARK: - Process Dancer Code
    @discardableResult
    func processInviteCode(_ code: String) -> Bool {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleanCode.hasPrefix("DNC-") else { return false }
        
        if !AuthManager.shared.isAuthenticated {
            UserDefaults.standard.set(cleanCode, forKey: "encore_pending_invite_code")
            return true
        }
        
        if cleanCode == UserProfileStore.shared.dancerCode {
            return false
        }
        
        isProcessingInvite = true
        
        Task {
            await fetchAndPresentInvite(code: cleanCode)
        }
        return true
    }
    
    // MARK: - Check Pending Invite After Login
    func checkPendingInviteAfterLogin() {
        guard AuthManager.shared.isAuthenticated else { return }
        let defaults = UserDefaults.standard
        if let pendingToken = defaults.string(forKey: "encore_pending_invite_token"), !pendingToken.isEmpty {
            defaults.removeObject(forKey: "encore_pending_invite_token")
            processInviteToken(pendingToken)
            return
        }
        if let pending = defaults.string(forKey: "encore_pending_invite_code"), !pending.isEmpty {
            defaults.removeObject(forKey: "encore_pending_invite_code")
            processInviteCode(pending)
        }
    }
    
    // MARK: - Deferred Deep Link Pasteboard Inspection
    private static let pasteboardCheckedKey = "encore.deferredInvitePasteboardChecked"

    /// An invite opened on the web before the app was installed leaves its link in the pasteboard; the app
    /// offers it once, the first time a signed-in user opens it. Later every copied link (YouTube, a website)
    /// would bring the sheet up again on each return to the app.
    func checkPasteboardForDeferredInvite() {
        let defaults = UserDefaults.standard
        guard AuthManager.shared.isAuthenticated, !defaults.bool(forKey: Self.pasteboardCheckedKey) else { return }
        defaults.set(true, forKey: Self.pasteboardCheckedKey)
        if UIPasteboard.general.hasURLs {
            self.showDeferredInvitePrompt = true
        }
    }
    
    func applyPastedURL(_ url: URL) {
        self.showDeferredInvitePrompt = false
        if AppWebsite.isOwn(url) {
            _ = handleIncomingURL(url)
        }
    }
    
    // MARK: - Fetch Token Preview from Supabase RPC
    private func fetchAndPresentTokenInvite(token: String) async {
        defer { isProcessingInvite = false }
        let client = SupabaseConfig.client
        
        do {
            struct PreviewParams: Encodable {
                let p_token: String
            }
            struct InviterData: Decodable {
                let name: String
                let club: String
                let avatar_url: String?
                let ksis_id: String?
                let dancer_code: String?
                let dancer_groups: [String]?
            }
            struct PreviewResponse: Decodable {
                let success: Bool
                let error_code: String?
                let message: String?
                let is_self: Bool?
                let already_connected: Bool?
                let is_pending: Bool?
                let inviter: InviterData?
            }
            
            let res: PreviewResponse = try await client.rpc(
                "get_friend_invite_preview",
                params: PreviewParams(p_token: token)
            ).execute().value
            
            if !res.success {
                if res.error_code == "REVOKED" {
                    self.inviteErrorMessage = "Tento QR kód bol zrušený a obnovený novým."
                } else if res.error_code == "EXPIRED" {
                    self.inviteErrorMessage = "Platnosť tohto QR kódu vypršala."
                } else {
                    self.inviteErrorMessage = "Pozvánka neexistuje alebo bola odstránená."
                }
                HapticFeedback.warning()
                return
            }
            
            if res.is_self == true {
                self.inviteErrorMessage = "Nemôžeš poslať pozvánku sám sebe."
                HapticFeedback.warning()
                return
            }
            
            if res.already_connected == true {
                self.inviteErrorMessage = "Tento tanečník už je vo vašich spojeniach."
                HapticFeedback.warning()
                return
            }
            
            if res.is_pending == true {
                self.inviteErrorMessage = "Pozvánka tomuto tanečníkovi už bola odoslaná."
                HapticFeedback.warning()
                return
            }
            
            guard let inviter = res.inviter else {
                self.inviteErrorMessage = "Dáta pozvánky nie sú dostupné."
                return
            }
            
            let payload = FriendInvitePayload(
                userId: inviter.dancer_code ?? token,
                name: inviter.name,
                club: inviter.club,
                action: "add_friend",
                ksisId: inviter.ksis_id,
                dancerCode: inviter.dancer_code,
                dancerGroups: inviter.dancer_groups ?? [],
                avatarURL: inviter.avatar_url,
                token: token
            )
            presentPayload(payload)
        } catch {
            self.inviteErrorMessage = "Nepodarilo sa overiť pozvánku: \(error.localizedDescription)"
            HapticFeedback.error()
        }
    }
    
    // MARK: - Respond to Incoming Invite (Send Request or Decline)
    /// Accepting never connects at once: a token or a dancer code sends a connection request, and the other
    /// person confirms it in Priatelia. Returns true when the request was sent (or already exists).
    /// Declining only closes the invite.
    func respondToIncomingInvite(accept: Bool) async -> Bool {
        guard let invite = incomingInvite else { return false }
        guard accept else {
            showInviteSheet = false
            incomingInvite = nil
            HapticFeedback.light()
            return true
        }

        isProcessingInvite = true
        inviteErrorMessage = nil
        defer { isProcessingInvite = false }

        do {
            if let token = invite.token {
                struct RPCParams: Encodable {
                    let p_token: String
                    let p_accept: Bool
                }
                struct RPCResponse: Decodable {
                    let success: Bool
                    let message: String?
                }
                let res: RPCResponse = try await SupabaseConfig.client.rpc(
                    "respond_to_friend_invite",
                    params: RPCParams(p_token: token, p_accept: true)
                ).execute().value
                guard res.success else {
                    inviteErrorMessage = res.message ?? "Žiadosť sa nepodarilo odoslať."
                    HapticFeedback.error()
                    return false
                }
            } else if let code = invite.dancerCode {
                try await ConnectionManager.shared.sendRequestByDancerCode(code: code, type: .connection)
            } else {
                inviteErrorMessage = "Pozvánka nie je platná."
                return false
            }
            await ConnectionManager.shared.fetchAllConnections()
            HapticFeedback.success()
            return true
        } catch {
            inviteErrorMessage = "Žiadosť sa nepodarilo odoslať: \(error.localizedDescription)"
            HapticFeedback.error()
            return false
        }
    }
    
    // MARK: - Fetch Dancer by Code & Present Confirm Sheet
    private func fetchAndPresentInvite(code: String) async {
        defer { isProcessingInvite = false }
        let dancers = await ConnectionManager.shared.searchDancers(query: code)
        guard let dancer = dancers.first(where: { $0.dancerCode.uppercased() == code }) else {
            inviteErrorMessage = "Tanečník s kódom \(code) sa nenašiel."
            HapticFeedback.warning()
            return
        }
        presentPayload(FriendInvitePayload(
            userId: dancer.id.uuidString,
            name: dancer.fullName,
            club: dancer.club,
            action: "add_friend",
            dancerCode: dancer.dancerCode,
            avatarURL: dancer.avatarUrl
        ))
    }
    
    private func presentPayload(_ payload: FriendInvitePayload) {
        self.incomingInvite = payload
        self.showInviteSheet = true
        HapticFeedback.light()
    }
}
