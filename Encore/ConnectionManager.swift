import Foundation
import SwiftUI
import OSLog
import Combine
import Supabase

// MARK: - Unified Connection Manager (Partners & Coach-Student)
@MainActor
public final class ConnectionManager: ObservableObject {
    public static let shared = ConnectionManager()
    
    @Published public var activePartners: [DancerConnection] = []
    @Published public var activeStudents: [DancerConnection] = []
    @Published public var activeCoaches: [DancerConnection] = []
    @Published public var incomingRequests: [DancerConnection] = []
    @Published public var outgoingRequests: [DancerConnection] = []
    
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Refresh connections when auth changes
        AuthManager.shared.$currentUser
            .map { $0?.id }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] userId in
                if userId != nil {
                    Task { [weak self] in
                        await self?.fetchAllConnections()
                    }
                } else {
                    self?.reset()
                }
            }
            .store(in: &cancellables)
    }
    
    public func reset() {
        activePartners = []
        activeStudents = []
        activeCoaches = []
        incomingRequests = []
        outgoingRequests = []
        errorMessage = nil
    }
    
    // MARK: - Fetch All Connections
    public func fetchAllConnections() async {
        guard let myId = AuthManager.shared.currentUser?.id else { return }
        isLoading = true
        defer { isLoading = false }
        
        let client = SupabaseConfig.client
        
        do {
            struct RawConnectionDTO: Decodable {
                let id: UUID
                let user_a_id: UUID
                let user_b_id: UUID
                let relationship_type: String
                let status: String
                let initiated_by: UUID
                let created_at: String?
                let updated_at: String?
            }
            
            let rawList: [RawConnectionDTO] = try await client
                .from("connections")
                .select("id, user_a_id, user_b_id, relationship_type, status, initiated_by, created_at, updated_at")
                .or("user_a_id.eq.\(myId),user_b_id.eq.\(myId)")
                .execute()
                .value
            
            // Gather all other user IDs to batch fetch their profiles
            var otherUserIds = Set<UUID>()
            for row in rawList {
                let other = row.user_a_id == myId ? row.user_b_id : row.user_a_id
                otherUserIds.insert(other)
            }
            
            // Fetch profiles for other users
            var profilesDict: [UUID: DancerSearchResult] = [:]
            if !otherUserIds.isEmpty {
                struct ProfileDTO: Decodable {
                    let id: UUID
                    let dancer_code: String?
                    let full_name: String?
                    let club: String?
                    let avatar_url: String?
                }
                
                let profiles: [ProfileDTO] = try await client
                    .from("profiles")
                    .select("id, dancer_code, full_name, club, avatar_url")
                    .in("id", values: Array(otherUserIds))
                    .execute()
                    .value
                
                for p in profiles {
                    profilesDict[p.id] = DancerSearchResult(
                        id: p.id,
                        dancerCode: p.dancer_code ?? "DNC-0000",
                        fullName: p.full_name ?? "Tanečník",
                        club: p.club ?? "",
                        avatarUrl: p.avatar_url
                    )
                }
            }
            
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            var partners: [DancerConnection] = []
            var students: [DancerConnection] = []
            var coaches: [DancerConnection] = []
            var incoming: [DancerConnection] = []
            var outgoing: [DancerConnection] = []
            
            for row in rawList {
                guard let relType = ConnectionRelationshipType(rawValue: row.relationship_type),
                      let st = ConnectionStatus(rawValue: row.status) else { continue }
                
                let otherId = row.user_a_id == myId ? row.user_b_id : row.user_a_id
                let otherProfile = profilesDict[otherId]
                
                let createdDate = row.created_at.flatMap { iso.date(from: $0) } ?? Date()
                let updatedDate = row.updated_at.flatMap { iso.date(from: $0) } ?? Date()
                
                let conn = DancerConnection(
                    id: row.id,
                    userAId: row.user_a_id,
                    userBId: row.user_b_id,
                    relationshipType: relType,
                    status: st,
                    initiatedBy: row.initiated_by,
                    createdAt: createdDate,
                    updatedAt: updatedDate,
                    otherUserId: otherId,
                    otherUserName: otherProfile?.fullName ?? "Tanečník",
                    otherUserClub: otherProfile?.club ?? "",
                    otherUserDancerCode: otherProfile?.dancerCode ?? "",
                    otherUserAvatarURL: otherProfile?.avatarUrl
                )
                
                if st == .pending {
                    if conn.initiatedBy == myId {
                        outgoing.append(conn)
                    } else {
                        incoming.append(conn)
                    }
                } else if st == .accepted {
                    switch relType {
                    case .partner:
                        partners.append(conn)
                    case .coachStudent:
                        if conn.userBId == myId {
                            // I am user_b = Coach, other is Student
                            students.append(conn)
                        } else {
                            // I am user_a = Student, other is Coach
                            coaches.append(conn)
                        }
                    }
                }
            }
            
            self.activePartners = partners
            self.activeStudents = students
            self.activeCoaches = coaches
            self.incomingRequests = incoming
            self.outgoingRequests = outgoing
            
        } catch {
            Logger.general.notice("fetchAllConnections: \(error.localizedDescription, privacy: .public)")
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Send Connection Request
    public func sendRequest(targetUserId: UUID, type: ConnectionRelationshipType) async throws {
        guard let myId = AuthManager.shared.currentUser?.id else {
            throw NSError(domain: "Encore", code: 401, userInfo: [NSLocalizedDescriptionKey: "Musíš byť prihlásený."])
        }
        guard targetUserId != myId else {
            throw NSError(domain: "Encore", code: 400, userInfo: [NSLocalizedDescriptionKey: "Nemôžeš sa prepojiť sám so sebou."])
        }
        
        let client = SupabaseConfig.client
        
        // Vzťahové zaradenie:
        // Pri coach_student: user_a_id = žiak, user_b_id = tréner.
        // Ak tréner posiela žiadosť žiakovi: user_a = žiak (target), user_b = tréner (myId)
        // Ak žiak posiela žiadosť trénerovi: user_a = žiak (myId), user_b = tréner (target)
        let userA: UUID
        let userB: UUID
        
        switch type {
        case .partner:
            // Zoradenie UUID pre deterministickú unikátnosť
            if myId.uuidString < targetUserId.uuidString {
                userA = myId
                userB = targetUserId
            } else {
                userA = targetUserId
                userB = myId
            }
        case .coachStudent:
            // The direction follows the role, not the plan: a coach invites a student, a dancer invites a coach.
            // (A dancer with Premium is still the student; the plan is personal.)
            if UserProfileStore.shared.isCoach {
                userA = targetUserId // Žiak (vlastník obsahu)
                userB = myId          // Tréner
            } else {
                userA = myId          // Žiak (ja)
                userB = targetUserId // Tréner (on)
            }
        }
        
        struct UpsertDTO: Encodable {
            let user_a_id: UUID
            let user_b_id: UUID
            let relationship_type: String
            let status: String
            let initiated_by: UUID
        }
        
        let payload = UpsertDTO(
            user_a_id: userA,
            user_b_id: userB,
            relationship_type: type.rawValue,
            status: ConnectionStatus.pending.rawValue,
            initiated_by: myId
        )
        
        try await client
            .from("connections")
            .upsert(payload)
            .execute()
        
        await fetchAllConnections()
    }
    
    /// Odoslať žiadosť vyhľadaním podľa kódu Dancer ID (napr. DNC-8492)
    public func sendRequestByDancerCode(code: String, type: ConnectionRelationshipType) async throws {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !clean.isEmpty else {
            throw NSError(domain: "Encore", code: 400, userInfo: [NSLocalizedDescriptionKey: "Zadaj platné ID tanečníka (napr. DNC-8492)."])
        }
        
        let results = await searchDancers(query: clean)
        // Only an exact code: a partial match must never send a request to someone else.
        guard let target = results.first(where: { $0.dancerCode.uppercased() == clean }) else {
            throw NSError(domain: "Encore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Tanečník s kódom \(clean) sa nenašiel."])
        }
        
        try await sendRequest(targetUserId: target.id, type: type)
    }
    
    // MARK: - Accept Request
    public func acceptRequest(connectionId: UUID) async throws {
        let client = SupabaseConfig.client
        
        struct UpdateDTO: Encodable {
            let status: String
            let updated_at: String
        }
        
        let payload = UpdateDTO(
            status: ConnectionStatus.accepted.rawValue,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("connections")
            .update(payload)
            .eq("id", value: connectionId)
            .execute()
        
        await fetchAllConnections()
    }
    
    // MARK: - Reject Request
    public func rejectRequest(connectionId: UUID) async throws {
        let client = SupabaseConfig.client
        
        struct UpdateDTO: Encodable {
            let status: String
            let updated_at: String
        }
        
        let payload = UpdateDTO(
            status: ConnectionStatus.rejected.rawValue,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("connections")
            .update(payload)
            .eq("id", value: connectionId)
            .execute()
        
        await fetchAllConnections()
    }
    
    // MARK: - Revoke Connection (Zrušiť prepojenie)
    public func revokeConnection(connectionId: UUID) async throws {
        let client = SupabaseConfig.client
        
        struct UpdateDTO: Encodable {
            let status: String
            let updated_at: String
        }
        
        let payload = UpdateDTO(
            status: ConnectionStatus.revoked.rawValue,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        try await client
            .from("connections")
            .update(payload)
            .eq("id", value: connectionId)
            .execute()
        
        await fetchAllConnections()
    }
    
    // MARK: - Search Dancers (RPC search_dancers)
    public func searchDancers(query: String) async -> [DancerSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        
        let client = SupabaseConfig.client
        
        do {
            struct Params: Encodable {
                let query: String
            }
            
            let res: [DancerSearchResult] = try await client
                .rpc("search_dancers", params: Params(query: trimmed))
                .execute()
                .value
            
            // Filter out myself
            let myId = AuthManager.shared.currentUser?.id
            return res.filter { $0.id != myId }
        } catch {
            Logger.general.notice("search_dancers RPC fallback: \(error.localizedDescription, privacy: .public)")
            
            // Direct query fallback if RPC function is not yet deployed
            do {
                struct SearchFallbackDTO: Decodable {
                    let id: UUID
                    let dancer_code: String?
                    let full_name: String?
                    let club: String?
                    let avatar_url: String?
                }
                
                let res: [SearchFallbackDTO] = try await client
                    .from("profiles")
                    .select("id, dancer_code, full_name, club, avatar_url")
                    .or("dancer_code.ilike.%\(trimmed)%,full_name.ilike.%\(trimmed)%")
                    .limit(10)
                    .execute()
                    .value
                
                let myId = AuthManager.shared.currentUser?.id
                return res.compactMap {
                    guard $0.id != myId else { return nil }
                    return DancerSearchResult(
                        id: $0.id,
                        dancerCode: $0.dancer_code ?? "DNC-0000",
                        fullName: $0.full_name ?? "Tanečník",
                        club: $0.club ?? "",
                        avatarUrl: $0.avatar_url
                    )
                }
            } catch {
                return []
            }
        }
    }
}
