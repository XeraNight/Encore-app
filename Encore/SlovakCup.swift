import Combine
import Foundation
import OSLog
import SwiftUI

// MARK: - Slovenský pohár: the official rules the app applies
/// Súťažný poriadok SZTŠ 2025, článok 23, with the 2026 changes (docs/KSIS_*): the series has 7 rounds, the best
/// rounds count (KSIS says how many, today 4), after the last round places 1–3 / 4–6 (juniors) and 1–8 / 9–12
/// (adults) may ask for a class one higher, the Superpohár (7th round) takes the first 24 juniors / 20 adults
/// after the 6th round, and the Majstrovstvá Slovenska need 3 rounds of the previous year.
/// The points themselves come only from the KSIS table; nothing here estimates them.
nonisolated enum SlovakCup {
    enum Group: String, Codable, Sendable {
        case juniors = "SLPJUN"
        case adults = "SLPDO"

        /// Juniori (I and II) dance the junior series; Mládež, Do 21 and Dospelí the adult one.
        init?(ageCategory: String?) {
            let category = (ageCategory ?? "").lowercased()
            if category.contains("junior") { self = .juniors }
            else if ["mládež", "do 21", "dospel"].contains(where: category.contains) { self = .adults }
            else { return nil }
        }
    }

    enum Discipline: String, CaseIterable, Identifiable, Sendable {
        case standard = "S"
        case latin = "L"

        var id: String { rawValue }
        var title: String { self == .standard ? "ŠTT" : "LAT" }
    }

    /// The disciplines the couple dances the cup in, from its KSIS age category and class (článok 23): adults
    /// in class B, A or S, Juniori I in D, C or B, Juniori II in D, C, B or A. Others are not in the cup.
    static func disciplines(for couple: UserCouple) -> [Discipline] {
        guard let group = Group(ageCategory: couple.ageCategory) else { return [] }
        let classes: Set<String> = switch group {
        case .adults: ["B", "A", "S"]
        case .juniors: (couple.ageCategory ?? "").contains("II") ? ["D", "C", "B", "A"] : ["D", "C", "B"]
        }
        return Discipline.allCases.filter { discipline in
            let className = discipline == .standard ? couple.stt.className : couple.lat.className
            return className.map { classes.contains($0.uppercased()) } ?? false
        }
    }

    static let roundsPerYear = 7
    static let roundsForChampionship = 3

    struct Target: Equatable, Identifiable, Sendable {
        let place: Int
        let title: String
        /// The couple's KSIS place is this one or better (a shared place counts from its first number).
        let reached: Bool
        /// Points to get ahead of the couple on that place; 0 when reached.
        let missing: Int
        var id: Int { place }
    }

    struct Status: Equatable, Sendable {
        let place: KSISPlace?
        let total: Int
        let danced: Int
        let held: Int
        let counted: Int?
        let targets: [Target]
    }

    static func targets(for group: Group) -> [(place: Int, title: String)] {
        switch group {
        case .juniors: return [(3, "právo na triedu A"), (6, "právo na triedu B"), (24, "Superpohár, po 6. kole")]
        case .adults: return [(8, "právo na triedu S"), (12, "právo na triedu A"), (20, "Superpohár, po 6. kole")]
        }
    }

    static func standingsURL(year: Int, group: Group, discipline: Discipline) -> URL? {
        URL(string: "https://szts.ksis.eu/slp_poradie.php?rok=\(year)&druh=\(group.rawValue)&s_l=\(discipline.rawValue)")
    }

    /// The couple's row: by its KSIS couple id, or by both names when the id is not known yet.
    static func entry(in standings: SlovakCupStandings, for couple: UserCouple) -> SlovakCupStandings.Entry? {
        if let id = couple.coupleId, let entry = standings.entries.first(where: { $0.parId == id }) { return entry }
        guard let names = couple.partnerNames.map(normalized) else { return nil }
        return standings.entries.first { normalized("\($0.partner) - \($0.partnerka)") == names }
    }

    static func status(of entry: SlovakCupStandings.Entry, in standings: SlovakCupStandings, group: Group) -> Status {
        let totals = standings.entries.map(\.total).sorted(by: >)
        let place = entry.place?.from ?? (totals.filter { $0 > entry.total }.count + 1)
        let targets = targets(for: group).map { target in
            let reached = place <= target.place || target.place > totals.count
            return Target(place: target.place, title: target.title, reached: reached,
                          missing: reached ? 0 : totals[target.place - 1] - entry.total + 1)
        }
        return Status(place: entry.place, total: entry.total, danced: entry.rounds.compactMap { $0 }.count,
                      held: standings.rounds.count, counted: standings.countedRounds, targets: targets)
    }

    private static func normalized(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "sk"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

// MARK: - Last standings read on this iPhone
/// The standings change only after a round, so the last table read in KSIS is kept and shown until the next read.
/// Public KSIS data; the couple's row is found again by the current couple, never stored as "ours".
@MainActor
final class SlovakCupStore: ObservableObject {
    static let shared = SlovakCupStore()

    struct Saved: Codable, Equatable {
        let standings: SlovakCupStandings
        let readAt: Date
    }

    @Published private(set) var saved: [String: Saved] = [:]
    private let key = "encore.slovakCup.standings"

    private init() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        do {
            saved = try JSONDecoder().decode([String: Saved].self, from: data)
        } catch {
            Logger.general.error("Slovak Cup cache unreadable: \(error.localizedDescription, privacy: .public)")
        }
    }

    func standings(group: SlovakCup.Group, discipline: SlovakCup.Discipline) -> Saved? {
        saved[Self.key(group, discipline)]
    }

    /// "5. v pohári ŠTT" for a couple found in the tables read so far (connections' couples too).
    func places(ofCouple parId: Int) -> [String] {
        SlovakCup.Discipline.allCases.flatMap { discipline in
            saved.filter { $0.key.hasSuffix(".\(discipline.rawValue)") }.values.compactMap { table in
                table.standings.entries.first { $0.parId == parId }?.place.map { "\($0.display) v pohári \(discipline.title)" }
            }
        }
    }

    func remember(_ standings: SlovakCupStandings) {
        guard let group = SlovakCup.Group(ageCategory: standings.category) else { return }
        let discipline: SlovakCup.Discipline = standings.category.lowercased().contains("latin") ? .latin : .standard
        saved[Self.key(group, discipline)] = Saved(standings: standings, readAt: Date())
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(saved), forKey: key)
        } catch {
            Logger.general.error("Slovak Cup cache not saved: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func key(_ group: SlovakCup.Group, _ discipline: SlovakCup.Discipline) -> String {
        "\(group.rawValue).\(discipline.rawValue)"
    }
}

// MARK: - The couple's place in the cup
struct SlovakCupStatusView: View {
    let status: SlovakCup.Status
    /// Shows the 3 rounds needed for the Majstrovstvá Slovenska (adults and Juniori II).
    let showsChampionship: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                fact(status.place?.display ?? "–", "miesto")
                fact("\(status.total)", "bodov")
                fact("\(status.danced) z \(status.held)", "kôl")
            }
            ForEach(status.targets) { target in
                line(target.reached ? "checkmark.circle.fill" : "arrow.up.circle",
                     target.reached ? Color.syncEmerald : Color.gold400,
                     "\(target.place). miesto (\(target.title)): " + (target.reached ? "máš ho" : "chýba \(target.missing) b"))
            }
            if showsChampionship {
                let enough = status.danced >= SlovakCup.roundsForChampionship
                line(enough ? "checkmark.circle.fill" : "exclamationmark.circle", enough ? Color.syncEmerald : Color.latinRed,
                     "Na MSR budúci rok treba \(SlovakCup.roundsForChampionship) kolá: máš \(status.danced)")
            }
            Text(footnote)
                .font(.caption)
                .foregroundColor(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footnote: String {
        let counted = status.counted.map { "Rátajú sa \($0) najlepšie kolá. " } ?? ""
        return counted + "Ostáva \(max(0, SlovakCup.roundsPerYear - status.held)) z \(SlovakCup.roundsPerYear) kôl. Právo na triedu platí podľa poradia po poslednom kole."
    }

    private func fact(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundColor(.white)
                .contentTransition(.numericText())
            Text(caption)
                .font(.caption2)
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .homeCard(cornerRadius: 12)
    }

    private func line(_ icon: String, _ color: Color, _ text: String) -> some View {
        Label {
            Text(text)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon).foregroundColor(color)
        }
    }
}
