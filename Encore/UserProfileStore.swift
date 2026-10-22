import Foundation
import SwiftUI
import OSLog
import Combine
import Supabase
import Auth

// MARK: - Per-Account Profile & Preferences Manager
// Isolates profile information (name, club, avatar, preferences) per account,
// ensuring no newly registered user inherits stale data from previous users or guest accounts.
@MainActor
final class UserProfileStore: ObservableObject {
    static let shared = UserProfileStore()
    
    @Published var currentName: String = ""
    @Published var currentClub: String = ""
    @Published var currentAvatarPath: String? = nil
    @Published var currentInviteCode: String = ""
    @Published var dancerCode: String = "DNC-0000"
    @Published var currentKsisId: String = ""
    @Published var dancerGroups: [String] = ["Štandardné tance", "Latinskoamerické tance"]
    @Published var cardTheme: String = "carmine_gold"
    @Published var currentPlaybackRate: Double = 1.0
    /// "dancer" or "coach" – what the user does (self-declared). It is a label, not a permission:
    /// coach powers come only from an accepted coach–student connection on the server.
    @Published var danceRole: String = "dancer"

    /// Coach tools are held back for a later version; until then everybody is a dancer in the app.
    var isCoach: Bool { AppFeatures.coachTools && danceRole == "coach" }

    static let clubMaxLength = 80
    
    var publicCardId: String {
        let cleanKsis = currentKsisId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanKsis.isEmpty {
            return "KSIS ID: \(cleanKsis)"
        }
        return "ID TANEČNÍKA: \(dancerCode)"
    }
    
    private var cancellables = Set<AnyCancellable>()
    /// The last profile download (account and time): a return to the app or to Profile reads the server at
    /// most every 10 minutes; a new account or a pull to refresh reads it at once.
    private var lastCloudFetch: (uid: String, at: Date)?
    private static let cloudFetchInterval: TimeInterval = 600

    private init() {
        refreshForActiveUser(force: true)

        // Another account or a sign-in/out (the first, current values are covered by the line above).
        AuthManager.shared.$currentUser
            .map { $0?.id }
            .removeDuplicates()
            .combineLatest(AuthManager.shared.$isAuthenticated.removeDuplicates())
            .dropFirst()
            // A sign-in changes both at once: one refresh, not two.
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshForActiveUser(force: true)
            }
            .store(in: &cancellables)
    }
    
    /// Unique identifier for the currently active session:
    /// - Authenticated Supabase UUID if logged in
    /// - Cleaned email address if available
    /// - "guest" for local offline mode
    /// .
    var activeUserId: String {
        if let id = AuthManager.shared.currentUser?.id.uuidString {
            return id.lowercased()
        }
        let email = AuthManager.shared.userEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !email.isEmpty {
            return email.replacingOccurrences(of: "@", with: "_").replacingOccurrences(of: ".", with: "_")
        }
        return "guest"
    }
    
    /// Loads the active account's profile from this iPhone, then from the server when it is due (or forced).
    func refreshForActiveUser(force: Bool = false) {
        let uid = activeUserId
        let defaults = UserDefaults.standard
        
        // 1. Name: Account-scoped, then Supabase metadata / AuthManager, then fallback
        let savedName = defaults.string(forKey: "profileName_\(uid)")
        if let savedName = savedName, !savedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            currentName = savedName
        } else if uid == "guest" {
            currentName = defaults.string(forKey: "profileName") ?? "Tanečník"
        } else {
            let fallbackName = AuthManager.shared.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            currentName = fallbackName.isEmpty ? "Tanečník" : fallbackName
        }
        
        // 2. Club: Account-scoped. Brand new accounts have NO club by default!
        if let savedClub = defaults.string(forKey: "profileClub_\(uid)") {
            currentClub = savedClub
        } else if uid == "guest" {
            currentClub = defaults.string(forKey: "profileClub") ?? ""
        } else {
            currentClub = "" // Never inherit another account's club
        }
        
        // 3. Avatar: Account-scoped. Brand new accounts have NO photo by default!
        if let savedAvatar = defaults.string(forKey: "profileAvatarPath_\(uid)"), !savedAvatar.isEmpty {
            currentAvatarPath = savedAvatar
        } else if uid == "guest" {
            currentAvatarPath = defaults.string(forKey: "profileImagePath")
        } else {
            currentAvatarPath = nil // Never inherit another account's photo
        }
        
        // 5. Playback Rate
        let savedRate = defaults.double(forKey: "profileRate_\(uid)")
        if savedRate > 0 {
            currentPlaybackRate = savedRate
        } else {
            let legacyRate = defaults.double(forKey: "defaultPlaybackRate")
            currentPlaybackRate = legacyRate > 0 ? legacyRate : 1.0
        }
        
        // 6. Invite Code, Dancer Code & KSIS ID
        let savedInvite = defaults.string(forKey: "profileInviteCode_\(uid)")
        currentInviteCode = savedInvite ?? ""
        let savedDancerCode = defaults.string(forKey: "profileDancerCode_\(uid)")
        if let dc = savedDancerCode, !dc.isEmpty {
            dancerCode = dc
        }
        let savedKsis = defaults.string(forKey: "profileKsisId_\(uid)")
        currentKsisId = savedKsis ?? ""
        if let groups = defaults.stringArray(forKey: "profileDancerGroups_\(uid)"), !groups.isEmpty {
            dancerGroups = groups
        }
        danceRole = defaults.string(forKey: "profileDanceRole_\(uid)") ?? "dancer"
        let savedTheme = defaults.string(forKey: "profileCardTheme_\(uid)")
        cardTheme = savedTheme ?? "carmine_gold"
        
        if force || lastCloudFetch?.uid != uid || Date().timeIntervalSince(lastCloudFetch?.at ?? .distantPast) > Self.cloudFetchInterval {
            lastCloudFetch = (uid, Date())
            Task { await self.fetchProfileCloudData() }
        }
    }

    /// Fetches the profile from Supabase in one request. The server copy of name and club wins, so a new iPhone
    /// shows the same profile and friends find the user by name, unless a change made here has not gone up yet:
    /// that one goes first and is never overwritten.
    func fetchProfileCloudData() async {
        let uid = activeUserId
        guard uid != "guest", let uuid = UUID(uuidString: uid) else { return }
        let hasPendingEdit = UserDefaults.standard.bool(forKey: Self.pendingKey(uid))
        if hasPendingEdit { await uploadProfile(uid: uid, uuid: uuid, name: currentName, club: currentClub) }

        do {
            struct ProfileCloudDTO: Decodable {
                let name: String?
                let club: String?
                let invite_code: String?
                let dancer_code: String?
                let ksis_id: String?
                let dancer_groups: [String]?
                let dance_role: String?
            }
            let res: ProfileCloudDTO = try await SupabaseConfig.client
                .from("profiles")
                .select("name, club, invite_code, dancer_code, ksis_id, dancer_groups, dance_role")
                .eq("id", value: uuid)
                .single()
                .execute()
                .value

            // The user may have switched accounts while the request was running: drop a late answer.
            guard uid == activeUserId else { return }

            if !UserDefaults.standard.bool(forKey: Self.pendingKey(uid)) {
                if let name = res.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                    self.currentName = name
                    UserDefaults.standard.set(name, forKey: "profileName_\(uid)")
                }
                if let club = res.club {
                    self.currentClub = club
                    UserDefaults.standard.set(club, forKey: "profileClub_\(uid)")
                }
            }
            
            if let code = res.invite_code, !code.isEmpty {
                self.currentInviteCode = code
                UserDefaults.standard.set(code, forKey: "profileInviteCode_\(uid)")
            }
            
            if let ksis = res.ksis_id, !ksis.isEmpty {
                self.currentKsisId = ksis
                UserDefaults.standard.set(ksis, forKey: "profileKsisId_\(uid)")
            }
            
            if let groups = res.dancer_groups, !groups.isEmpty {
                self.dancerGroups = groups
                UserDefaults.standard.set(groups, forKey: "profileDancerGroups_\(uid)")
            }
            
            // The Dancer ID is generated by the database and cannot be changed by the client.
            if let dCode = res.dancer_code, !dCode.isEmpty {
                self.dancerCode = dCode
                UserDefaults.standard.set(dCode, forKey: "profileDancerCode_\(uid)")
            }
            danceRole = res.dance_role == "coach" ? "coach" : "dancer"
            UserDefaults.standard.set(danceRole, forKey: "profileDanceRole_\(uid)")
        } catch {
            Logger.general.notice("fetchProfileCloudData: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func pendingKey(_ uid: String) -> String { "profilePendingUpload_\(uid)" }

    /// Name and club to the server; a failure leaves them marked, so the next download sends them first.
    private func uploadProfile(uid: String, uuid: UUID, name: String, club: String) async {
        struct ProfileUpdate: Encodable { let name: String; let club: String }
        do {
            // RLS lets users update only their own row; the server trigger keeps role and status untouchable.
            try await SupabaseConfig.client
                .from("profiles")
                .update(ProfileUpdate(name: name, club: club))
                .eq("id", value: uuid)
                .execute()
            UserDefaults.standard.removeObject(forKey: Self.pendingKey(uid))
        } catch {
            Logger.general.error("Profile upload failed, kept for later: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Changes the self-declared role (Tanečník / Tréner) on this phone and on the server.
    func setDanceRole(_ role: String) {
        let uid = activeUserId
        let clean = role == "coach" ? "coach" : "dancer"
        danceRole = clean
        UserDefaults.standard.set(clean, forKey: "profileDanceRole_\(uid)")
        guard let uuid = UUID(uuidString: uid) else { return }
        Task {
            struct RoleUpdate: Encodable { let dance_role: String }
            do {
                try await SupabaseConfig.client
                    .from("profiles")
                    .update(RoleUpdate(dance_role: clean))
                    .eq("id", value: uuid)
                    .execute()
            } catch {
                Logger.general.error("setDanceRole failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    /// Saves name and club on this phone and on the server (card, friends search, coach lists).
    func saveProfile(name: String, club: String) {
        let uid = activeUserId
        let trimmedName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(NameRules.maxLength))
        let trimmedClub = String(club.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.clubMaxLength))
        
        let finalName = trimmedName.isEmpty ? "Tanečník" : trimmedName
        currentName = finalName
        currentClub = trimmedClub
        
        let defaults = UserDefaults.standard
        defaults.set(finalName, forKey: "profileName_\(uid)")
        defaults.set(trimmedClub, forKey: "profileClub_\(uid)")
        
        // Keep AuthManager and global fallback in sync
        AuthManager.shared.userName = finalName
        defaults.set(finalName, forKey: "profileName")
        if uid == "guest" {
            defaults.set(trimmedClub, forKey: "profileClub")
        }

        guard let uuid = UUID(uuidString: uid) else { return }
        defaults.set(true, forKey: Self.pendingKey(uid))
        Task { await uploadProfile(uid: uid, uuid: uuid, name: finalName, club: trimmedClub) }
    }
    
    /// Updates or clears avatar image path for the active account
    func setAvatarPath(_ path: String?) {
        let uid = activeUserId
        let defaults = UserDefaults.standard
        
        currentAvatarPath = path
        if let path = path, !path.isEmpty {
            defaults.set(path, forKey: "profileAvatarPath_\(uid)")
            if uid == "guest" {
                defaults.set(path, forKey: "profileImagePath")
            }
        } else {
            defaults.removeObject(forKey: "profileAvatarPath_\(uid)")
            if uid == "guest" {
                defaults.removeObject(forKey: "profileImagePath")
            }
        }
    }
    
    /// Updates preferred video playback rate for the active account
    func setPlaybackRate(_ rate: Double) {
        let uid = activeUserId
        currentPlaybackRate = rate
        UserDefaults.standard.set(rate, forKey: "profileRate_\(uid)")
        UserDefaults.standard.set(rate, forKey: "defaultPlaybackRate")
    }
}
