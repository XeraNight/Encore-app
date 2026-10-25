import Foundation
import SwiftUI

// MARK: - Connection Relationship Type
public enum ConnectionRelationshipType: String, CaseIterable, Codable, Sendable {
    case connection = "connection"       // Spojenie: no access to the other person's things
    case partner = "partner"             // The dance partner, only one (shared routines: AppFeatures.partnerRoutines)
    case coachStudent = "coach_student"  // Jednosmerný prístup (Tréner -> Zverenec)

    public var title: String {
        switch self {
        case .connection: return "Spojenie"
        case .partner: return "Partner / partnerka"
        case .coachStudent: return "Tréner & Zverenec"
        }
    }

    public var badgeIcon: String {
        switch self {
        case .connection: return "person.2.fill"
        case .partner: return "figure.dance"
        case .coachStudent: return "graduationcap.fill"
        }
    }

    /// What a pending request asks for, as the invited person reads it.
    public var requestText: String {
        switch self {
        case .connection: return "Chce sa s tebou spojiť"
        case .partner: return "Chce si ťa označiť ako svoj tanečný pár"
        case .coachStudent: return "Chce sa prepojiť ako tréner"
        }
    }
}

// MARK: - Connection Status
public enum ConnectionStatus: String, Codable, Sendable {
    case pending = "pending"       // Čaká na potvrdenie protistranou
    case accepted = "accepted"     // Aktívne overené prepojenie
    case rejected = "rejected"     // Odmietnutá žiadosť
    case revoked = "revoked"       // Zrušené prepojenie (bývalý partner / ukončený tréning)
    
    public var isPending: Bool { self == .pending }
    public var isAccepted: Bool { self == .accepted }
    
    public var displayTitle: String {
        switch self {
        case .pending: return "Čaká na schválenie"
        case .accepted: return "Prepojené"
        case .rejected: return "Odmietnuté"
        case .revoked: return "Zrušené"
        }
    }
    
    public var color: Color {
        switch self {
        case .pending: return Color.orange
        case .accepted: return Color.syncEmerald
        case .rejected: return Color.latinCrimson
        case .revoked: return Color.gray
        }
    }
}

// MARK: - Dancer Connection Record
public struct DancerConnection: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let userAId: UUID            // Vlastník obsahu (žiak / iniciátor páru)
    public let userBId: UUID            // Prístupujúci (tréner / tanečný partner)
    public let relationshipType: ConnectionRelationshipType
    public var status: ConnectionStatus
    public let initiatedBy: UUID
    public let createdAt: Date
    public let updatedAt: Date
    
    // UI Metadata o protistrane (dopĺňané pri načítaní)
    public var otherUserId: UUID
    public var otherUserName: String
    public var otherUserClub: String
    public var otherUserDancerCode: String
    public var otherUserAvatarURL: String?
    
    public init(
        id: UUID = UUID(),
        userAId: UUID,
        userBId: UUID,
        relationshipType: ConnectionRelationshipType,
        status: ConnectionStatus = .pending,
        initiatedBy: UUID,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        otherUserId: UUID,
        otherUserName: String = "Tanečník",
        otherUserClub: String = "",
        otherUserDancerCode: String = "",
        otherUserAvatarURL: String? = nil
    ) {
        self.id = id
        self.userAId = userAId
        self.userBId = userBId
        self.relationshipType = relationshipType
        self.status = status
        self.initiatedBy = initiatedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.otherUserId = otherUserId
        self.otherUserName = otherUserName
        self.otherUserClub = otherUserClub
        self.otherUserDancerCode = otherUserDancerCode
        self.otherUserAvatarURL = otherUserAvatarURL
    }
    
    /// Určí, či je táto žiadosť prichádzajúca pre daného používateľa
    public func isIncoming(for myUserId: UUID) -> Bool {
        return status == .pending && initiatedBy != myUserId && (userAId == myUserId || userBId == myUserId)
    }
    
    /// Určí, či je táto žiadosť odchádzajúca od daného používateľa
    public func isOutgoing(for myUserId: UUID) -> Bool {
        return status == .pending && initiatedBy == myUserId
    }
    
    /// Určí, či vystupujem ako tréner v tomto prepojení
    public func amICoach(myUserId: UUID) -> Bool {
        return relationshipType == .coachStudent && userBId == myUserId
    }
    
    /// Určí, či vystupujem ako zverenec v tomto prepojení
    public func amIStudent(myUserId: UUID) -> Bool {
        return relationshipType == .coachStudent && userAId == myUserId
    }
}

// MARK: - Dancer Search Result (from RPC search_dancers)
public struct DancerSearchResult: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let dancerCode: String
    public let fullName: String
    public let club: String
    public let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case dancerCode = "dancer_code"
        case fullName = "full_name"
        case club
        case avatarUrl = "avatar_url"
    }
    
    public init(
        id: UUID,
        dancerCode: String,
        fullName: String,
        club: String,
        avatarUrl: String? = nil
    ) {
        self.id = id
        self.dancerCode = dancerCode
        self.fullName = fullName
        self.club = club
        self.avatarUrl = avatarUrl
    }

    /// A dancer without a club or code yet (null on the server) must not drop the whole list.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        dancerCode = try container.decodeIfPresent(String.self, forKey: .dancerCode) ?? ""
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName) ?? "Tanečník"
        club = try container.decodeIfPresent(String.self, forKey: .club) ?? ""
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
    }
}

// MARK: - Connection Invite Payload (pre QR kód a Deep link)
public struct ConnectionInvitePayload: Codable, Equatable, Sendable {
    public let dancerCode: String
    public let name: String
    public let club: String
    public let relationshipType: ConnectionRelationshipType
    
    public init(
        dancerCode: String,
        name: String,
        club: String = "",
        relationshipType: ConnectionRelationshipType = .partner
    ) {
        self.dancerCode = dancerCode
        self.name = name
        self.club = club
        self.relationshipType = relationshipType
    }
}
