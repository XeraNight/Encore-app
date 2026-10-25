import Foundation
import SwiftUI
import OSLog
import Combine
import Supabase

// MARK: - Unified Connection Manager (connections, the partner, coach and student)
/// A plain connection gives no access to the other person's things; only the partner (one) shares routines.
@MainActor
public final class ConnectionManager: ObservableObject {
    public static let shared = ConnectionManager()
    
    @Published public var activeConnections: [DancerConnection] = []
    /// One partner; older accounts may still have more until they turn the rest into connections.
    @Published public var activePartners: [DancerConnection] = []
    @Published public var activeStudents: [DancerConnection] = []
    @Published public var activeCoaches: [DancerConnection] = []
    @Published public var incomingRequests: [DancerConnection] = []
    @Published public var outgoingRequests: [DancerConnection] = []
    /// Dancers I blocked (App Review 1.2), shown with "Odblokovať".
    @Published public private(set) var blockedDancers: [DancerSearchResult] = []
    /// The KSIS couple each connected person linked (class and points, public in KSIS), by user id.
    @Published private(set) var couplesByUser: [UUID: UserCouple] = [:]
    
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
        sharingKnown = nil
        UserDefaults.standard.removeObject(forKey: Self.sharingKey)
        activeConnections = []
        activePartners = []
        activeStudents = []
        activeCoaches = []
        incomingRequests = []
        outgoingRequests = []
        blockedDancers = []
        couplesByUser = [:]
        errorMessage = nil
    }
    
    // MARK: - Is anyone else in my routines?
    private static let sharingKey = "encore.hasSharingConnection"
    private var sharingKnown: Bool?

    /// Whether someone else can open my routines or I theirs (an accepted partner, coach or student; a plain
    /// connection does not count). Asked at most once per session with one tiny count query, then remembered;
    /// offline the last answer is used.
    public func hasSharingConnection() async -> Bool {
        if let sharingKnown { return sharingKnown }
        do {
            let count = try await SupabaseConfig.client
                .from("connections")
                .select("id", head: true, count: .exact)
                .eq("status", value: "accepted")
                .in("relationship_type", values: [ConnectionRelationshipType.partner.rawValue, ConnectionRelationshipType.coachStudent.rawValue])
                .execute()
                .count ?? 0
            rememberSharing(count > 0)
            return count > 0
        } catch {
            return UserDefaults.standard.bool(forKey: Self.sharingKey)
        }
    }

    private func rememberSharing(_ shared: Bool) {
        sharingKnown = shared
        UserDefaults.standard.set(shared, forKey: Self.sharingKey)
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
            
            struct BlockRow: Decodable { let blocked_id: UUID }
            /// A connected person's KSIS couple; RLS returns only the couples of people I am connected with.
            struct CoupleRow: Decodable {
                let userId: UUID
                let couple: UserCouple
                init(from decoder: Decoder) throws {
                    struct Key: CodingKey {
                        var stringValue: String
                        var intValue: Int? { nil }
                        init(stringValue: String) { self.stringValue = stringValue }
                        init?(intValue: Int) { nil }
                    }
                    userId = try decoder.container(keyedBy: Key.self).decode(UUID.self, forKey: Key(stringValue: "user_id"))
                    couple = try UserCouple(from: decoder)
                }
            }

            // Four reads at once instead of one after another.
            async let rows: [RawConnectionDTO] = client
                .from("connections")
                .select("id, user_a_id, user_b_id, relationship_type, status, initiated_by, created_at, updated_at")
                .or("user_a_id.eq.\(myId),user_b_id.eq.\(myId)")
                .execute()
                .value
            // Names and photos of the people in these rows and of blocked dancers. Profiles are private, so a
            // server function returns just these people (related_profiles).
            async let people: [DancerSearchResult] = client.rpc("related_profiles").execute().value
            async let blocked: [BlockRow] = client.from("user_blocks").select("blocked_id").execute().value
            async let couples: [CoupleRow] = client.from("user_couples").select().neq("user_id", value: myId).eq("is_current", value: true).execute().value

            let (rawList, related, blocks) = try await (rows, people, blocked)
            let profilesDict = Dictionary(related.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            // The KSIS line is extra: without it the list still shows.
            self.couplesByUser = Dictionary(((try? await couples) ?? []).map { ($0.userId, $0.couple) }, uniquingKeysWith: { first, _ in first })
            self.blockedDancers = blocks.map {
                profilesDict[$0.blocked_id]
                    ?? DancerSearchResult(id: $0.blocked_id, dancerCode: "", fullName: "Tanečník", club: "", avatarUrl: nil)
            }

            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            var plain: [DancerConnection] = []
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
                    case .connection:
                        plain.append(conn)
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
            
            // Someone who is my partner is not listed again as a plain connection.
            let partnerIds = Set(partners.map(\.otherUserId))
            self.activeConnections = plain.filter { !partnerIds.contains($0.otherUserId) }
            self.activePartners = partners
            self.activeStudents = students
            self.activeCoaches = coaches
            rememberSharing(!(partners.isEmpty && students.isEmpty && coaches.isEmpty))
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
        case .connection, .partner:
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
        
        do {
            // An earlier rejected or revoked request between the two is asked again.
            try await client
                .from("connections")
                .upsert(payload, onConflict: "user_a_id,user_b_id,relationship_type")
                .execute()
        } catch let error as PostgrestError where error.code == "42501" {
            // Refused on the server (for example a block either way); the reason is not revealed.
            throw NSError(domain: "Encore", code: 403, userInfo: [NSLocalizedDescriptionKey: "Žiadosť sa nedá poslať."])
        } catch let error as PostgrestError where error.hint == "already_has_partner" {
            throw NSError(domain: "Encore", code: 409, userInfo: [NSLocalizedDescriptionKey: error.message])
        }
        
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
        
        do {
            try await client
                .from("connections")
                .update(payload)
                .eq("id", value: connectionId)
                .execute()
        } catch let error as PostgrestError where error.hint == "already_has_partner" {
            throw NSError(domain: "Encore", code: 409, userInfo: [NSLocalizedDescriptionKey: error.message])
        }
        
        await fetchAllConnections()
    }

    // MARK: - Partner back to a plain connection
    /// Either side; the access to each other's routines ends at once (make_plain_connection on the server).
    public func makePlainConnection(connectionId: UUID) async throws {
        struct Params: Encodable { let p_connection_id: UUID }
        try await SupabaseConfig.client.rpc("make_plain_connection", params: Params(p_connection_id: connectionId)).execute()
        rememberSharing(activePartners.count > 1 || !activeStudents.isEmpty || !activeCoaches.isEmpty)
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
    
    // MARK: - Block (App Review 1.2)
    /// Ends every connection and request with the dancer, refuses new ones either way and hides both from
    /// each other's search (user_blocks, enforced on the server). The other dancer is not told.
    public func block(_ dancerId: UUID) async throws {
        guard let myId = AuthManager.shared.currentUser?.id else { return }
        let client = SupabaseConfig.client

        struct BlockDTO: Encodable {
            let blocker_id: UUID
            let blocked_id: UUID
        }
        try await client
            .from("user_blocks")
            .upsert(BlockDTO(blocker_id: myId, blocked_id: dancerId), onConflict: "blocker_id,blocked_id", ignoreDuplicates: true)
            .execute()

        struct UpdateDTO: Encodable {
            let status: String
            let updated_at: String
        }
        try await client
            .from("connections")
            .update(UpdateDTO(status: ConnectionStatus.revoked.rawValue, updated_at: ISO8601DateFormatter().string(from: Date())))
            .in("status", values: [ConnectionStatus.pending.rawValue, ConnectionStatus.accepted.rawValue])
            .or("and(user_a_id.eq.\(myId),user_b_id.eq.\(dancerId)),and(user_a_id.eq.\(dancerId),user_b_id.eq.\(myId))")
            .execute()

        await fetchAllConnections()
    }

    public func unblock(_ dancerId: UUID) async throws {
        guard let myId = AuthManager.shared.currentUser?.id else { return }
        try await SupabaseConfig.client
            .from("user_blocks")
            .delete()
            .eq("blocker_id", value: myId)
            .eq("blocked_id", value: dancerId)
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
            Logger.general.notice("search_dancers failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
