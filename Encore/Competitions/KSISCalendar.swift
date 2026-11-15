import Combine
import Foundation
import OSLog
import SwiftData

// MARK: - KSIS competition calendar
/// One line of the KSIS calendar (menu.php?akcia=KS). The calendar is public and nothing from it belongs to a user,
/// so it is read here on the iPhone and never goes through Encore's server. Everything shown comes from KSIS.
nonisolated struct KSISEvent: Codable, Equatable, Identifiable, Sendable {
    /// KSIS marks the row with a class: sppoz… Slovenský pohár, msrpoz MSR, wdsfpoz WDSF, sztspoz courses and seminars.
    enum Kind: String, Codable, Sendable {
        case competition, slovakCup, championship, wdsf, other
    }

    /// `id_prop`, the key of the propositions, entry list and timetable pages; nil for a line without them.
    let propId: Int?
    let name: String
    /// yyyy-MM-dd
    let date: String
    /// "Miesto konania" as KSIS writes it, often a full address.
    let venue: String
    /// The town found in `venue`; nil abroad or for a place not in `SlovakCity`, never a guess.
    let city: String?
    let organizer: String
    /// "Termín prihlášok", yyyy-MM-dd.
    let entryDeadline: String?
    /// The red "Pozor zmena !!!" line.
    let note: String?
    /// "Dospelí D ŠTT" and so on, exactly as KSIS lists them.
    let categories: [String]
    let kind: Kind
    let isCancelled: Bool
    /// The number in "Zoznam prihlásených (139)".
    let registered: Int?
    /// KSIS shows the Harmonogram link only once the timetable is published.
    let hasTimetable: Bool

    var id: String { propId.map(String.init) ?? "\(date) \(name)" }
}

// MARK: - Reading the page
nonisolated enum KSISCalendarPage {
    enum Failure: Error, Equatable {
        /// KSIS shows its check for robots: the person passes it in the visible page, nothing here tries to.
        case challenge
        /// Not the page this reader knows: better no calendar than a guessed one.
        case layoutChanged
    }

    /// Same markers as the server's `isChallengePage` (supabase/functions/_shared/ksis-pages.ts).
    private static let challengeMarkers = [
        "just a moment", "cf-wrapper", "challenges.cloudflare.com", "attention required! | cloudflare", "_cf_chl_opt",
        "prebieha bezpečnostné overenie",
    ]

    static func isChallengePage(_ html: String) -> Bool {
        let lower = html.lowercased()
        return challengeMarkers.contains { lower.contains($0) }
    }

    /// The calendar of a year is about 50 kB. A page far bigger is not the calendar, and is not read.
    private static let maxPageSize = 1_500_000

    static func parse(_ html: String) throws -> [KSISEvent] {
        if isChallengePage(html) { throw Failure.challenge }
        // The filter form is on every calendar page, also on one with no competition in the period.
        guard html.utf8.count <= maxPageSize, html.contains("name=\"vekova_ktg\"") else { throw Failure.layoutChanged }
        // One row at a time. A pattern run over the whole page searches to the page's end from every row start, so a
        // page of the wrong shape kept the app busy for minutes.
        let rows = html.components(separatedBy: "<tr").dropFirst().compactMap { ("<tr" + $0).prefixMatch(of: row) }
        let events = rows.compactMap { event(rowClass: String($0.1), dateCell: String($0.2), body: String($0.3)) }
        guard events.count == rows.count else { throw Failure.layoutChanged }
        return events
    }

    private static let row = /<tr[^>]*>\s*<td([^>]*)valign="top"[^>]*>\s*<strong>(.*?)<\/strong>\s*<\/td>\s*<td[^>]*valign="top"[^>]*>(.*?)<\/td>\s*<\/tr>/
        .dotMatchesNewlines()

    private static func event(rowClass: String, dateCell: String, body: String) -> KSISEvent? {
        guard let date = isoDate(dateCell),
              let name = body.firstMatch(of: /<font color="#0000FF"><strong>(.*?)<\/strong>/.dotMatchesNewlines()).map({ plain(String($0.1)) }),
              !name.isEmpty else { return nil }
        let links = body.firstRange(of: "pull-right").map { String(body[$0.lowerBound...]) } ?? ""
        let venue = body.firstMatch(of: /Miesto konania:(.*?)<\/strong>/.dotMatchesNewlines()).map { plain(String($0.1)) } ?? ""
        return KSISEvent(
            propId: links.firstMatch(of: /id_prop=(\d+)/).flatMap { Int($0.1) },
            name: name,
            date: date,
            venue: venue,
            city: SlovakCity.find(in: venue)?.name,
            organizer: body.firstMatch(of: /Organizátor:(.*?)<\/strong>/.dotMatchesNewlines()).map { plain(String($0.1)) } ?? "",
            entryDeadline: body.firstMatch(of: /Termín prihlášok:\s*(\d{2}\.\d{2}\.\d{4})/).flatMap { isoDate(String($0.1)) },
            note: body.firstMatch(of: /<font color="red">(.*?)<\/font>/.dotMatchesNewlines()).map { plain(String($0.1)) },
            categories: categories(in: body),
            kind: kind(of: rowClass),
            isCancelled: dateCell.contains("zrusene"),
            registered: links.firstMatch(of: /Zoznam prihlásených \((\d+)\)/).flatMap { Int($0.1) },
            hasTimetable: links.contains("propharmonogram.php")
        )
    }

    private static func kind(of rowClass: String) -> KSISEvent.Kind {
        if rowClass.contains("msrpoz") { return .championship }
        if rowClass.contains("sppoz") { return .slovakCup }
        if rowClass.contains("wdsfpoz") { return .wdsf }
        if rowClass.contains("sztspoz") { return .other }
        return .competition
    }

    /// The comma list after the bold lines and the red note, before the links.
    private static func categories(in body: String) -> [String] {
        let start = body.firstRange(of: "<p>")?.lowerBound ?? body.firstRange(of: "pull-right")?.lowerBound ?? body.endIndex
        let text = String(body[..<start])
            .replacing(/<strong>.*?<\/strong>/.dotMatchesNewlines(), with: "")
            .replacing(/<font.*?<\/font>/.dotMatchesNewlines(), with: "")
        let tail = text.components(separatedBy: "<br>").last ?? ""
        return plain(tail).split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static func isoDate(_ text: String) -> String? {
        text.firstMatch(of: /(\d{2})\.(\d{2})\.(\d{4})/).map { "\($0.3)-\($0.2)-\($0.1)" }
    }

    /// Text without tags, entities decoded, single spaces.
    private static func plain(_ html: String) -> String {
        html.replacing(/<br\s*\/?>/, with: " ")
            .replacing(/<[^>]+>/, with: "")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacing(/\s+/, with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Pages of one competition
extension KSISEvent {
    var dateValue: Date? { Self.day(date) }
    var entryDeadlineValue: Date? { entryDeadline.flatMap(Self.day) }
    var isCompetition: Bool { kind != .other }

    private static func day(_ iso: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = PlannerCalendar.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: iso)
    }

    /// The whole calendar from today, a year ahead. Filtered here, so one page serves every filter.
    static func calendarURL(from date: Date = Date()) -> URL? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd.MM.yyyy"
        let end = PlannerCalendar.calendar.date(byAdding: .month, value: 13, to: date) ?? date
        return KSISBrowserView.page("menu.php?akcia=KS&dt_od=\(formatter.string(from: date))&dt_do=\(formatter.string(from: end))"
            + "&vekova_ktg=&trieda=&druh_sut=&typ_sut=&sut_akcia=ALL")
    }

    static func propositionsURL(_ propId: Int) -> URL? { KSISBrowserView.page("prop.php?id_prop=\(propId)") }
    static func entriesURL(_ propId: Int) -> URL? { KSISBrowserView.page("zoznam_prihl.php?id_prop=\(propId)") }
    static func timetableURL(_ propId: Int) -> URL? { KSISBrowserView.page("propharmonogram.php?id_prop=\(propId)") }

    /// A Google Maps search for the place: a plain link, free and without a key. Only the address leaves the app.
    static func mapsURL(venue: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/maps/search/")
        components?.queryItems = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "query", value: venue)]
        return components?.url
    }
}

// MARK: - The couple's categories
extension KSISEvent {
    /// The categories of this competition the couple dances by its KSIS age category and classes, as KSIS writes
    /// them ("Dospelí D ŠTT"), and the Slovenský pohár when the couple is in it. Nothing else is assumed: who may
    /// start in another class or at MSR is in the rules, not here.
    func categories(for couple: UserCouple) -> [String] {
        let names = Self.ownCategoryNames(for: couple)
        return categories.filter { names.contains(Self.folded($0)) }
    }

    private static func ownCategoryNames(for couple: UserCouple) -> Set<String> {
        guard let age = couple.ageCategory?.trimmingCharacters(in: .whitespaces), !age.isEmpty else { return [] }
        var names: Set<String> = []
        for (className, discipline) in [(couple.stt.className, "ŠTT"), (couple.lat.className, "LAT")] {
            guard let className, !className.isEmpty else { continue }
            names.insert(folded("\(age) \(className) \(discipline)"))
            names.insert(folded("\(age) \(className)"))   // class E has no discipline
        }
        let cup = SlovakCup.Group(ageCategory: couple.ageCategory) == .juniors ? "SP JUN" : "SP"
        for discipline in SlovakCup.disciplines(for: couple) {
            names.insert(folded("\(cup) \(discipline == .standard ? "ŠTT" : "LAT")"))
        }
        return names
    }

    private static func folded(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "sk"))
    }
}

// MARK: - Filter
/// The calendar's filters, the same as KSIS's own and the city from the map.
struct KSISCalendarFilter: Equatable {
    static let ages = ["Deti I", "Deti II", "Junior I", "Junior II", "Mládež", "Do 21", "Dospelí", "Senior"]
    static let classes = ["E", "D", "C", "B", "A", "S"]
    static let disciplines = ["ŠTT", "LAT"]

    var onlyMine = true
    var age: String?
    var className: String?
    var discipline: String?
    var kind: KSISEvent.Kind?
    var city: String?

    func matches(_ event: KSISEvent, couple: UserCouple?) -> Bool {
        guard event.isCompetition else { return false }
        if onlyMine, let couple, event.categories(for: couple).isEmpty { return false }
        if let kind, event.kind != kind { return false }
        if let city, event.city != city { return false }
        guard age != nil || className != nil || discipline != nil else { return true }
        return event.categories.contains(where: categoryMatches)
    }

    private func categoryMatches(_ category: String) -> Bool {
        let words = category.split(separator: " ").map(String.init)
        if let age, !(category + " ").hasPrefix(age + " ") && !(category + " ").contains(" \(age) ") { return false }
        if let className, !words.contains(className) { return false }
        if let discipline, !words.contains(discipline) { return false }
        return true
    }
}

// MARK: - Last calendar read
/// The last calendar read from KSIS stays on this iPhone, so it opens at once and works without internet.
@MainActor
final class KSISCalendarStore: ObservableObject {
    static let shared = KSISCalendarStore()

    private struct Saved: Codable {
        let events: [KSISEvent]
        let readAt: Date
    }

    @Published private(set) var events: [KSISEvent] = []
    @Published private(set) var readAt: Date?
    private let key = "encore.ksisCalendar"

    private init() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        do {
            let saved = try JSONDecoder().decode(Saved.self, from: data)
            events = saved.events
            readAt = saved.readAt
        } catch {
            Logger.general.error("KSIS calendar cache unreadable: \(error.localizedDescription, privacy: .public)")
        }
    }

    func remember(_ events: [KSISEvent]) {
        self.events = events
        readAt = Date()
        if let context = AppContainer.shared?.mainContext { PlannedCompetition.follow(events, context: context) }
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(Saved(events: events, readAt: Date())), forKey: key)
        } catch {
            Logger.general.error("KSIS calendar cache not saved: \(error.localizedDescription, privacy: .public)")
        }
    }

    func event(propId: Int?) -> KSISEvent? {
        guard let propId else { return nil }
        return events.first { $0.propId == propId }
    }
}
