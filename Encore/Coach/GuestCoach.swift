import Foundation
import SwiftUI
import Combine
import Supabase
import OSLog

// MARK: - Guest coach key
/// A dancer lends one routine to a guest coach (a seminar) through a random key in a QR code. The guest
/// sees figure names and rhythm only and writes own notes, which stay with the dancer after the key ends.
/// Free: one active key for up to 7 days; Plus and Premium: any number for up to 30 days. The server
/// enforces all of it (migration 20261009_coach_lessons_and_guest_keys.sql).
enum GuestCoachLink {
    /// `encore://guest?k=<32 hex>`; scanned with Encore's QR scanner or opened as a link.
    static func url(token: String) -> URL? {
        var components = URLComponents()
        components.scheme = "encore"
        components.host = "guest"
        components.queryItems = [URLQueryItem(name: "k", value: token)]
        return components.url
    }

    static func token(from text: String) -> String? {
        guard let components = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme == "encore", components.host == "guest",
              let token = components.queryItems?.first(where: { $0.name == "k" })?.value?.lowercased(),
              token.count == 32, token.allSatisfy(\.isHexDigit) else { return nil }
        return token
    }

    /// Longest key a plan may make (the server checks the same).
    static func maxDays(for tier: SubscriptionTier) -> Int { tier == .free ? 7 : 30 }
}

struct GuestCoachKey: Identifiable, Decodable, Equatable, Sendable {
    let id: UUID
    let routineId: UUID
    let expiresAt: Date
    let createdAt: Date
    let revokedAt: Date?
    let guestName: String?
    let redeemedAt: Date?
    let routine: RoutineName?

    struct RoutineName: Decodable, Equatable, Sendable {
        let name: String
        let danceName: String

        enum CodingKeys: String, CodingKey {
            case name
            case danceName = "dance_name"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case routineId = "routine_id"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case revokedAt = "revoked_at"
        case guestName = "guest_name"
        case redeemedAt = "redeemed_at"
        case routine = "routines"
    }

    var isActive: Bool { revokedAt == nil && expiresAt > Date() }
}

struct GuestFigure: Identifiable, Decodable, Sendable {
    let nodeId: UUID
    let figureName: String
    let rhythm: String
    let orderIndex: Int

    var id: UUID { nodeId }

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case figureName = "figure_name"
        case rhythm
        case orderIndex = "order_index"
    }
}

struct GuestNote: Identifiable, Decodable, Sendable {
    let id: UUID
    let keyId: UUID
    let nodeId: UUID
    let body: String
    let createdAt: Date
    let key: KeyName?

    struct KeyName: Decodable, Sendable {
        let guestName: String?

        enum CodingKeys: String, CodingKey { case guestName = "guest_name" }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case keyId = "key_id"
        case nodeId = "node_id"
        case body
        case createdAt = "created_at"
        case key = "guest_coach_keys"
    }
}

/// What the guest got after using a key.
struct GuestAccess: Identifiable, Decodable, Sendable, Hashable {
    let keyId: UUID
    let routineId: UUID
    let routineName: String
    let danceName: String
    let ownerName: String
    let expiresAt: Date

    var id: UUID { keyId }

    enum CodingKeys: String, CodingKey {
        case keyId = "key_id"
        case routineId = "routine_id"
        case routineName = "routine_name"
        case danceName = "dance_name"
        case ownerName = "owner_name"
        case expiresAt = "expires_at"
    }
}

// MARK: - Service
@MainActor
final class GuestCoachService: ObservableObject {
    static let shared = GuestCoachService()

    /// A key scanned or opened as a link, waiting for Home to show it.
    @Published var pendingToken: String?

    enum Failure: LocalizedError {
        case message(String)

        var errorDescription: String? {
            switch self {
            case .message(let text): return text
            }
        }
    }

    private var client: SupabaseClient { SupabaseConfig.client }

    // Dancer
    func createKey(for routine: Routine, days: Int) async throws -> (key: GuestCoachKey, link: URL) {
        await SupabaseSyncManager.shared.syncRoutineNow(routine)   // the routine must be on the server
        struct Params: Encodable { let p_routine_id: UUID; let p_days: Int }
        struct Created: Decodable { let key_id: UUID; let token: String; let expires_at: Date }
        do {
            let created: [Created] = try await client
                .rpc("create_guest_coach_key", params: Params(p_routine_id: routine.id, p_days: days))
                .execute()
                .value
            guard let first = created.first, let link = GuestCoachLink.url(token: first.token) else {
                throw Failure.message("Kľúč sa nepodarilo vytvoriť.")
            }
            let keys = try await keys(for: routine.id)
            guard let key = keys.first(where: { $0.id == first.key_id }) else {
                throw Failure.message("Kľúč sa nepodarilo vytvoriť.")
            }
            return (key, link)
        } catch let error as Failure {
            throw error
        } catch {
            throw Self.translate(error)
        }
    }

    func keys(for routineId: UUID) async throws -> [GuestCoachKey] {
        do {
            return try await client
                .from("guest_coach_keys")
                .select("id, routine_id, expires_at, created_at, revoked_at, guest_name, redeemed_at")
                .eq("routine_id", value: routineId)
                .order("created_at", ascending: false)
                .execute()
                .value
        } catch {
            throw Self.translate(error)
        }
    }

    func revoke(_ keyId: UUID) async throws {
        struct Params: Encodable { let p_key_id: UUID }
        do {
            try await client.rpc("revoke_guest_coach_key", params: Params(p_key_id: keyId)).execute()
        } catch {
            throw Self.translate(error)
        }
    }

    /// Notes guests left on one figure of my routine.
    func notes(forNode nodeId: UUID) async throws -> [GuestNote] {
        do {
            return try await client
                .from("guest_coach_notes")
                .select("id, key_id, node_id, body, created_at, guest_coach_keys(guest_name)")
                .eq("node_id", value: nodeId)
                .order("created_at")
                .execute()
                .value
        } catch {
            throw Self.translate(error)
        }
    }

    // Guest
    func redeem(_ token: String) async throws -> GuestAccess {
        struct Params: Encodable { let p_token: String }
        do {
            let rows: [GuestAccess] = try await client
                .rpc("redeem_guest_coach_key", params: Params(p_token: token))
                .execute()
                .value
            guard let access = rows.first else { throw Failure.message("Kľúč nie je platný.") }
            return access
        } catch let error as Failure {
            throw error
        } catch {
            throw Self.translate(error)
        }
    }

    /// Routines lent to me that I can still open.
    func myAccess() async throws -> [GuestCoachKey] {
        guard let me = AuthManager.shared.currentUser?.id else { return [] }
        do {
            return try await client
                .from("guest_coach_keys")
                .select("id, routine_id, expires_at, created_at, revoked_at, guest_name, redeemed_at, routines(name, dance_name)")
                .eq("guest_id", value: me)
                .is("revoked_at", value: nil)
                .gt("expires_at", value: ISO8601DateFormatter().string(from: Date()))
                .order("expires_at")
                .execute()
                .value
        } catch {
            throw Self.translate(error)
        }
    }

    func figures(of routineId: UUID) async throws -> [GuestFigure] {
        struct Params: Encodable { let p_routine_id: UUID }
        do {
            return try await client
                .rpc("guest_routine_figures", params: Params(p_routine_id: routineId))
                .execute()
                .value
        } catch {
            throw Self.translate(error)
        }
    }

    func myNotes(in routineId: UUID) async throws -> [GuestNote] {
        guard let me = AuthManager.shared.currentUser?.id else { return [] }
        do {
            return try await client
                .from("guest_coach_notes")
                .select("id, key_id, node_id, body, created_at")
                .eq("routine_id", value: routineId)
                .eq("author_id", value: me)
                .order("created_at")
                .execute()
                .value
        } catch {
            throw Self.translate(error)
        }
    }

    func addNote(_ body: String, keyId: UUID, routineId: UUID, nodeId: UUID) async throws {
        struct Row: Encodable { let key_id: UUID; let routine_id: UUID; let node_id: UUID; let body: String }
        do {
            try await client
                .from("guest_coach_notes")
                .insert(Row(key_id: keyId, routine_id: routineId, node_id: nodeId, body: body))
                .execute()
        } catch {
            throw Self.translate(error)
        }
    }

    /// Server reasons → one Slovak sentence.
    private static func translate(_ error: Error) -> Failure {
        let text = String(describing: error)
        Logger.sync.error("Guest coach request failed: \(error.localizedDescription, privacy: .public)")
        if text.contains("free_limit") {
            return .message("Vo Free môžeš mať naraz jeden aktívny kľúč. Zruš starý alebo prejdi na Plus.")
        }
        if text.contains("days_out_of_range") {
            return .message("Takú dlhú platnosť tvoj plán nemá.")
        }
        if text.contains("invalid_key") { return .message("Kľúč neplatí: vypršal, bol zrušený alebo je chybný.") }
        if text.contains("key_used") { return .message("Tento kľúč už použil iný tréner.") }
        if text.contains("own_key") { return .message("Toto je tvoj vlastný kľúč. Pošli ho trénerovi.") }
        if text.contains("not_owner") { return .message("Kľúč sa dá vytvoriť len k vlastnej zostave.") }
        if text.contains("PGRST202") || text.contains("42P01") {
            return .message("Táto funkcia ešte nie je zapnutá na serveri.")
        }
        return .message("Nepodarilo sa. Skontroluj internet a skús to znova.")
    }
}
