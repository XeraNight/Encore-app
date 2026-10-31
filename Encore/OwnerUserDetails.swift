import SwiftUI
import Supabase
import OSLog

// MARK: - Owner console: one account for support
/// What support needs about one account: sign-in, KSIS (verify both ways, unlink), couples and connections to remove,
/// what is in the cloud and the owner's earlier actions. State and counts only, never the content of notes or diaries.
/// Every action is an owner function on the server (`owner_*`), which checks the owner again and writes the record.
struct OwnerUserDetailsView: View {
    let userId: UUID
    /// Changes after every owner action, so the card shows the new state and the new record entry.
    let reload: Int
    let isBusy: Bool
    /// The console's runner: shows the result and counts the success.
    let run: (@escaping () async throws -> String) -> Void

    @State private var card: OwnerUserCard?
    @State private var loadFailed = false
    @State private var removal: Removal?

    private enum Removal: Identifiable {
        case unlink(OwnerUserCard.Dancer), couple(OwnerUserCard.Couple), connection(OwnerUserCard.Connection)

        var id: String {
            switch self {
            case .unlink(let dancer): "unlink-\(dancer.personNumber)"
            case .couple(let couple): "couple-\(couple.id)"
            case .connection(let connection): "connection-\(connection.id)"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let card {
                accountSection(card)
                ksisSection(card)
                if !card.couples.isEmpty { couplesSection(card.couples) }
                if !card.connections.isEmpty { connectionsSection(card.connections) }
                cloudSection(card)
                if !card.actions.isEmpty { actionsSection(card.actions) }
            } else if loadFailed {
                Text("Kartu sa nepodarilo načítať. Skontroluj pripojenie.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.65))
            } else {
                ProgressView()
                    .tint(Color.gold400)
                    .frame(maxWidth: .infinity)
            }
        }
        .task(id: "\(userId)-\(reload)") { await load() }
        .alert(removalTitle, isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }),
               presenting: removal) { removal in
            Button(removalButton(removal), role: .destructive) { remove(removal) }
            Button("Zrušiť", role: .cancel) {}
        } message: { removal in
            Text(removalMessage(removal))
        }
    }

    // MARK: Sections
    private func accountSection(_ card: OwnerUserCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionHeader(title: "ÚČET", systemImage: "person.crop.circle")
            line(card.emailConfirmed ? "E-mail potvrdený" : "E-mail nepotvrdený",
                 systemImage: card.emailConfirmed ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                 tint: card.emailConfirmed ? Color.syncEmerald : Color.gold300)
            line("Prihlásenie: \(card.signInMethods)", systemImage: "key.fill")
            line("Naposledy: \(card.lastSignInAt.map(Self.dateTime) ?? "nikdy")", systemImage: "clock.fill")
            line("Účet od \(Self.date(card.createdAt))" + (card.appVersion.map { " · appka \($0)" } ?? ""),
                 systemImage: "calendar")
        }
    }

    private func ksisSection(_ card: OwnerUserCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "KSIS", systemImage: "person.text.rectangle")
            if let dancer = card.dancer {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(dancer.name) · č. \(dancer.personNumber)")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    Text([dancer.club, dancer.verificationText].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(dancer.isVerified ? Color.syncEmerald : Color.gold300)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    if dancer.isVerified {
                        actionButton("Zrušiť overenie", systemImage: "arrow.uturn.backward") {
                            setDancer(status: "pending", done: "Overenie \(dancer.name) je zrušené.")
                        }
                    } else {
                        actionButton("Overiť", systemImage: "checkmark.seal.fill") {
                            setDancer(status: "verified", done: "\(dancer.name) je overený.")
                        }
                    }
                    actionButton("Odpojiť", systemImage: "link", destructive: true) { removal = .unlink(dancer) }
                }
            } else {
                line("Nie je prepojený s KSIS.", systemImage: "minus.circle")
            }
        }
    }

    private func couplesSection(_ couples: [OwnerUserCard.Couple]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionHeader(title: "PÁRY", systemImage: "person.2.fill", count: couples.count)
            ForEach(couples) { couple in
                removableRow(title: [couple.numberText, couple.partnerNames].compactMap { $0 }.joined(separator: " · "),
                             subtitle: [couple.isCurrent ? "Aktuálny" : "Predchádzajúci", "súťaže: \(couple.results)"]
                                .joined(separator: " · ")) {
                    removal = .couple(couple)
                }
            }
        }
    }

    private func connectionsSection(_ connections: [OwnerUserCard.Connection]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionHeader(title: "SPOJENIA", systemImage: "link", count: connections.count)
            ForEach(connections) { connection in
                removableRow(title: connection.name.isEmpty ? "Bez mena" : connection.name,
                             subtitle: [connection.typeTitle, connection.status == "pending" ? "čaká" : nil]
                                .compactMap { $0 }.joined(separator: " · ")) {
                    removal = .connection(connection)
                }
            }
        }
    }

    private func cloudSection(_ card: OwnerUserCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionHeader(title: "V CLOUDE", systemImage: "icloud.fill")
            line((["Zostavy \(card.routines)", "Figúry \(card.figures)"] + card.recordCounts).joined(separator: " · "),
                 systemImage: "square.stack.3d.up.fill")
            line("Posledná synchronizácia: \(card.lastSync.map(Self.dateTime) ?? "nikdy")",
                 systemImage: "arrow.triangle.2.circlepath")
        }
    }

    private func actionsSection(_ actions: [OwnerAction]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionHeader(title: "ZÁSAHY", systemImage: "list.bullet.rectangle")
            ForEach(actions) { OwnerActionRow(action: $0, showsTarget: false) }
        }
    }

    // MARK: Pieces
    private func line(_ text: String, systemImage: String, tint: Color = Color.gold300) -> some View {
        Label {
            Text(text)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundColor(tint)
        }
    }

    private func removableRow(title: String, subtitle: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
            Spacer(minLength: 8)
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.latinRed)
                    .frame(width: 40, height: 40)
                    .background(Color.latinRed.opacity(0.12), in: Circle())
            }
            .buttonStyle(.pressable)
            .disabled(isBusy)
            .accessibilityLabel("Odobrať")
        }
        .padding(10)
        .homeCard(cornerRadius: 14)
    }

    private func actionButton(_ title: String, systemImage: String, destructive: Bool = false,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundColor(destructive ? Color.latinRed : Color.gold400)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background((destructive ? Color.latinRed : Color.gold400).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.pressable(scale: 0.97))
        .disabled(isBusy)
    }

    // MARK: Removal question
    private var removalTitle: String {
        switch removal {
        case .unlink: "Odpojiť od KSIS?"
        case .couple: "Odobrať pár?"
        case .connection: "Zrušiť spojenie?"
        case nil: ""
        }
    }

    private func removalButton(_ removal: Removal) -> String {
        switch removal {
        case .unlink: "Odpojiť"
        case .couple: "Odobrať pár"
        case .connection: "Zrušiť spojenie"
        }
    }

    private func removalMessage(_ removal: Removal) -> String {
        switch removal {
        case .unlink(let dancer):
            "Účet už nebude \(dancer.name). Overenie zmizne a v KSIS sa môže nájsť znova."
        case .couple(let couple):
            "\(couple.numberText ?? "Pár") zmizne aj so súťažami (\(couple.results)). Zo stránky KSIS si ho môže uložiť znova."
        case .connection(let connection):
            "Spojenie s \(connection.name.isEmpty ? "týmto účtom" : connection.name) sa zruší rovnako, ako keby ho zrušil sám."
        }
    }

    // MARK: Server
    private func load() async {
        struct Params: Encodable { let p_user: UUID }
        do {
            card = try await SupabaseConfig.client.rpc("owner_user_card", params: Params(p_user: userId)).execute().value
            loadFailed = false
        } catch {
            guard !Task.isCancelled else { return }
            Logger.general.error("Owner user card failed: \(error.localizedDescription, privacy: .public)")
            loadFailed = true
        }
    }

    private func setDancer(status: String, done: String) {
        run {
            struct Params: Encodable { let p_user: UUID; let p_status: String }
            do {
                try await SupabaseConfig.client
                    .rpc("owner_set_dancer", params: Params(p_user: userId, p_status: status)).execute()
            } catch let error as PostgrestError where error.code == "23505" {
                throw OwnerConsoleError.dancerTaken
            }
            return done
        }
    }

    private func remove(_ removal: Removal) {
        switch removal {
        case .unlink:
            setDancer(status: "none", done: "Účet je odpojený od KSIS.")
        case .couple(let couple):
            run {
                struct Params: Encodable { let p_user: UUID; let p_couple: UUID }
                try await SupabaseConfig.client
                    .rpc("owner_remove_couple", params: Params(p_user: userId, p_couple: couple.id)).execute()
                return "\(couple.numberText ?? "Pár") je odobratý."
            }
        case .connection(let connection):
            run {
                struct Params: Encodable { let p_user: UUID; let p_connection: UUID }
                try await SupabaseConfig.client
                    .rpc("owner_remove_connection", params: Params(p_user: userId, p_connection: connection.id)).execute()
                return "Spojenie je zrušené."
            }
        }
    }

    // MARK: Dates
    private static let slovak = Locale(identifier: "sk")
    static func date(_ date: Date) -> String {
        date.formatted(.dateTime.day().month().year().locale(slovak))
    }
    static func dateTime(_ date: Date) -> String {
        date.formatted(.dateTime.day().month().year().hour().minute().locale(slovak))
    }
}

// MARK: - The owner record
/// One owner action, from a user's card or the whole record (`owner_recent_actions`, which also names the account).
struct OwnerAction: Decodable, Equatable, Identifiable {
    let action: String
    let detail: String?
    let createdAt: Date
    let targetUserId: UUID?
    let targetName: String?

    var id: String { "\(createdAt.timeIntervalSince1970)-\(action)-\(targetUserId?.uuidString ?? "")" }

    var title: String {
        switch action {
        case "grant_plan": "Plán"
        case "ban": "Zablokovaný"
        case "unban": "Odblokovaný"
        case "verify_dancer": "Overený v KSIS"
        case "unverify_dancer": "Overenie zrušené"
        case "unlink_dancer": "Odpojený od KSIS"
        case "remove_connection": "Zrušené spojenie"
        case "remove_couple": "Odobratý pár"
        case "delete_account": "Účet zmazaný"
        default: action
        }
    }

    /// A removed connection names its kind by the server value.
    var detailText: String? {
        guard action == "remove_connection" else { return detail }
        return detail.flatMap { ConnectionRelationshipType(rawValue: $0)?.title } ?? detail
    }

    enum CodingKeys: String, CodingKey {
        case action, detail
        case createdAt = "created_at", targetUserId = "target_user_id", targetName = "target_name"
    }
}

struct OwnerActionRow: View {
    let action: OwnerAction
    let showsTarget: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text([action.title, showsTarget ? (action.targetName ?? "zmazaný účet") : nil]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white)
                if let detail = action.detailText, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Text(OwnerUserDetailsView.dateTime(action.createdAt))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

// MARK: - Models
struct OwnerUserCard: Decodable, Equatable {
    struct Dancer: Decodable, Equatable {
        let personNumber: Int
        let name: String
        let club: String?
        let status: String
        let verifiedHow: String?
        let verifiedAt: Date?
        let verifiedByName: String?

        var isVerified: Bool { status == "verified" }

        var verificationText: String {
            guard isVerified else { return "čaká na overenie" }
            let how = switch verifiedHow {
            case "owner": "overil majiteľ"
            case "partner": "overil partner \(verifiedByName ?? "")"
            case "vouch": "overený naživo: \(verifiedByName ?? "")"
            default: "overený"
            }
            return how.trimmingCharacters(in: .whitespaces) + (verifiedAt.map { " \(OwnerUserDetailsView.date($0))" } ?? "")
        }

        enum CodingKeys: String, CodingKey {
            case name, club, status
            case personNumber = "person_number", verifiedHow = "verified_how", verifiedAt = "verified_at",
                 verifiedByName = "verified_by_name"
        }
    }

    struct Couple: Decodable, Equatable, Identifiable {
        let id: UUID
        let pairNumber: Int?
        let partnerNames: String?
        let isCurrent: Bool
        let results: Int

        var numberText: String? { pairNumber.map { "Pár č. \(String(format: "%05d", $0))" } }

        enum CodingKeys: String, CodingKey {
            case id, results
            case pairNumber = "pair_number", partnerNames = "partner_names", isCurrent = "is_current"
        }
    }

    struct Connection: Decodable, Equatable, Identifiable {
        let id: UUID
        let name: String
        let type: String
        let status: String

        var typeTitle: String { ConnectionRelationshipType(rawValue: type)?.title ?? type }
    }

    let emailConfirmed: Bool
    let providers: [String]
    let createdAt: Date
    let lastSignInAt: Date?
    let appVersion: String?
    let dancer: Dancer?
    let couples: [Couple]
    let connections: [Connection]
    let routines: Int
    let figures: Int
    /// Backed-up rows by kind (`DeviceBackup`).
    let records: [String: Int]
    let lastSync: Date?
    let actions: [OwnerAction]

    var signInMethods: String {
        providers.map { provider in
            switch provider {
            case "apple": "Apple"
            case "google": "Google"
            case "email": "e-mail"
            default: provider
            }
        }.joined(separator: ", ")
    }

    var recordCounts: [String] {
        let names = [InstantNote.backupKind: "Poznámky", TrainingLogEntry.backupKind: "Reflexie",
                     PlannedSession.backupKind: "Tréningy v pláne", PlannedCompetition.backupKind: "Súťaže v pláne",
                     LessonPriority.backupKind: "Priority", TrainingCadence.backupKind: "Rytmus"]
        return records.sorted { $0.key < $1.key }.map { "\(names[$0.key] ?? $0.key) \($0.value)" }
    }

    enum CodingKeys: String, CodingKey {
        case providers, dancer, couples, connections, routines, figures, records, actions
        case emailConfirmed = "email_confirmed", createdAt = "created_at", lastSignInAt = "last_sign_in_at",
             appVersion = "app_version", lastSync = "last_sync"
    }
}

/// The console's top line (`owner_overview`).
struct OwnerOverview: Decodable, Equatable {
    let users: Int
    let newThisWeek: Int
    let verified: Int
    let plus: Int
    let premium: Int

    enum CodingKeys: String, CodingKey {
        case users, verified, plus, premium
        case newThisWeek = "new_this_week"
    }
}

enum OwnerConsoleError: LocalizedError {
    case dancerTaken
    var errorDescription: String? { "tohto tanečníka už má overený iný účet." }
}
