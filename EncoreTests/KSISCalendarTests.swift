import Testing
import SwiftData
import Foundation
@testable import Encore

/// The KSIS calendar read from a real page (fixtures/ksis/calendar.html, saved 7. 11. 2026): every line, its address,
/// deadline, categories and links; the couple's own categories; the filters; a robot check is never a calendar.
@MainActor
struct KSISCalendarTests {
    private func fixture() throws -> [KSISEvent] {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try KSISCalendarPage.parse(String(contentsOf: root.appending(path: "fixtures/ksis/calendar.html"), encoding: .utf8))
    }

    private func couple(age: String, stt: String?, lat: String?) throws -> UserCouple {
        let json = """
        {"id":"\(UUID().uuidString)","is_current":true,"pair_number":95397,"age_category":"\(age)",
         "stt_class":\(stt.map { "\"\($0)\"" } ?? "null"),"lat_class":\(lat.map { "\"\($0)\"" } ?? "null")}
        """
        return try JSONDecoder().decode(UserCouple.self, from: Data(json.utf8))
    }

    @Test func readsEveryLineOfTheRealPage() throws {
        let events = try fixture()
        #expect(events.count == 46)
        let cup = try #require(events.first { $0.propId == 2406 })
        #expect(cup.name == "VIVA DANCE FESTIVAL - 6.kolo Slovenský pohár")
        #expect(cup.date == "2026-11-07")
        #expect(cup.venue == "ŠH Milénium, Nové Zámky")
        #expect(cup.organizer == "TŠK VIVA Nové Zámky")
        #expect(cup.kind == .slovakCup)
        #expect(cup.registered == 139)
        #expect(cup.hasTimetable)
        #expect(cup.categories.contains("Dospelí B ŠTT"))
        #expect(cup.categories.contains("SP ŠTT"))
    }

    @Test func aChangeNoteAndAPlainCompetition() throws {
        let events = try fixture()
        let changed = try #require(events.first { $0.propId == 2410 })
        #expect(changed.note == "Pozor zmena !!! Zmena harmonogramu")
        #expect(changed.kind == .competition)
        #expect(!changed.categories.contains { $0.contains("Pozor") })
        let optima = try #require(events.first { $0.propId == 2277 })
        #expect(optima.venue == "OC Optima, Moldavská cesta 32, Košice")
        #expect(!optima.hasTimetable)
    }

    @Test func aCancelledCourseIsNotACompetition() throws {
        let cancelled = try fixture().filter(\.isCancelled)
        #expect(!cancelled.isEmpty)
        #expect(cancelled.allSatisfy { $0.categories.isEmpty })
        #expect(cancelled.contains { !$0.isCompetition })
    }

    @Test func aCoupleSeesItsOwnCategoriesOnly() throws {
        let adultsD = try couple(age: "Dospelí", stt: "D", lat: "D")
        let optima = try #require(try fixture().first { $0.propId == 2277 })
        #expect(optima.categories(for: adultsD) == ["Dospelí D ŠTT", "Dospelí D LAT"])
        let cup = try #require(try fixture().first { $0.propId == 2406 })
        #expect(cup.categories(for: adultsD).isEmpty)
    }

    @Test func aCategoryOfTheRealPageThatIsNotListedIsMissingFromAPlan() throws {
        let optima = try #require(try fixture().first { $0.propId == 2277 })
        #expect(optima.missing(from: ["Dospelí D ŠTT", "Dospelí A ŠTT"]) == ["Dospelí A ŠTT"])
    }

    @Test func aCoupleInTheCupSeesItsRound() throws {
        let adultsB = try couple(age: "Dospelí", stt: "B", lat: "C")
        let cup = try #require(try fixture().first { $0.propId == 2406 })
        #expect(Set(cup.categories(for: adultsB)) == ["Dospelí B ŠTT", "SP ŠTT"])
    }

    @Test func filtersWorkTogether() throws {
        let events = try fixture()
        let couple = try couple(age: "Dospelí", stt: "D", lat: "D")
        let mine = events.filter { KSISCalendarFilter().matches($0, couple: couple) }
        #expect(!mine.isEmpty)
        #expect(mine.allSatisfy { !$0.categories(for: couple).isEmpty })
        var cup = KSISCalendarFilter(onlyMine: false)
        cup.kind = .slovakCup
        #expect(events.filter { cup.matches($0, couple: couple) }.allSatisfy { $0.kind == .slovakCup })
        var juniors = KSISCalendarFilter(onlyMine: false)
        juniors.age = "Junior I"
        juniors.className = "D"
        juniors.discipline = "LAT"
        let found = events.filter { juniors.matches($0, couple: nil) }
        #expect(found.allSatisfy { $0.categories.contains("Junior I D LAT") })
    }

    @Test func aCourseNeverShowsAmongCompetitions() throws {
        let events = try fixture()
        #expect(events.contains { $0.kind == .other })
        #expect(!events.contains { $0.kind == .other && KSISCalendarFilter(onlyMine: false).matches($0, couple: nil) })
    }

    @Test func aRobotCheckIsNeverACalendar() {
        #expect(throws: KSISCalendarPage.Failure.challenge) {
            try KSISCalendarPage.parse("<title>Len chvíľu...</title>Prebieha bezpečnostné overenie")
        }
        #expect(throws: KSISCalendarPage.Failure.layoutChanged) {
            try KSISCalendarPage.parse("<html>iná stránka</html>")
        }
    }

    @Test func mapsLinkCarriesOnlyTheAddress() throws {
        let url = try #require(KSISEvent.mapsURL(venue: "OC Optima, Moldavská cesta 32, Košice"))
        #expect(url.absoluteString.hasPrefix("https://www.google.com/maps/search/?api=1&query=OC%20Optima"))
    }
}

/// The town in a free-text KSIS address: real addresses from the calendar, and a street named after another town.
@MainActor
struct SlovakCityTests {
    @Test func theNumberOfACompetitionIsReadFromAnyOfItsPages() throws {
        #expect(KSISEvent.propId(in: try #require(KSISEvent.entriesURL(2271))) == 2271)
        #expect(KSISEvent.propId(in: try #require(KSISEvent.propositionsURL(2406))) == 2406)
        #expect(KSISEvent.propId(in: try #require(KSISEvent.timetableURL(2410))) == 2410)
        #expect(KSISEvent.propId(in: try #require(URL(string: "https://szts.ksis.eu/menu.php?akcia=KS"))) == nil)
        #expect(KSISEvent.propId(in: try #require(URL(string: "https://szts.ksis.eu/zoznam_prihl.php?id_prop=abc"))) == nil)
    }

    @Test func findsTheTownInRealAddresses() {
        let addresses = [
            "ŠH Milénium, Nové Zámky": "Nové Zámky",
            "OC Optima, Moldavská cesta 32, Košice": "Košice",
            "Košice, Spoločenský pavilón, Trieda SNP 61": "Košice",
            "ZŠ Kysucká 14, 903 01 Senec": "Senec",
            "Centrum univerzitného športu SPU v Nitre, Chalupkova 359": "Nitra",
            "Mestská špotová hala TRNAVA, Rybníková 576/15, 917 01": "Trnava",
            "Športová hala, Javorínska 1952/19 Nové Mesto nad Váhom 91501": "Nové Mesto nad Váhom",
            "Telocvičňa Základnej školy Turany": "Turany",
            "MsKC Žiar nad Hronom, ul SNP 119": "Žiar nad Hronom",
        ]
        for (venue, town) in addresses {
            #expect(SlovakCity.find(in: venue)?.name == town, "\(venue)")
        }
    }

    @Test func aStreetNamedAfterATownIsNotThatTown() {
        #expect(SlovakCity.find(in: "Trnavská 12, Bratislava")?.name == "Bratislava")
    }

    @Test func anUnknownPlaceHasNoPin() {
        #expect(SlovakCity.find(in: "Konkurz") == nil)
        #expect(SlovakCity.find(in: "Sporthalle, Wien") == nil)
    }
}

/// Pins around Bratislava must end up apart and inside the map, and a lone pin must stay on its town.
@MainActor
struct SlovakiaMapLayoutTests {
    private let size = CGSize(width: 372, height: 190)

    private func points(_ names: [String]) -> [CGPoint] {
        SlovakCity.all.filter { names.contains($0.name) }.map {
            SlovakiaOutline.point(longitude: $0.longitude, latitude: $0.latitude, in: size)
        }
    }

    @Test func nearTownsMoveApartAndStayOnTheMap() {
        let towns = points(["Bratislava", "Pezinok", "Senec", "Šamorín", "Trnava", "Galanta", "Dunajská Streda"])
        let spread = SlovakiaMapView.spreadOut(towns, spacing: 28, in: size)
        for first in spread.indices {
            #expect((14...(size.width - 14)).contains(spread[first].x))
            #expect((14...(size.height - 14)).contains(spread[first].y))
            for second in spread.indices where second > first {
                #expect(hypot(spread[first].x - spread[second].x, spread[first].y - spread[second].y) >= 27)
            }
        }
    }

    @Test func aPinWithRoomStaysOnItsTown() {
        let towns = points(["Košice", "Žilina"])
        #expect(SlovakiaMapView.spreadOut(towns, spacing: 28, in: size) == towns)
    }
}

/// Idem from the KSIS calendar: one competition in Kalendár however many times it is sent there.
@MainActor
struct GoingFromKSISTests {
    private func context() throws -> ModelContext {
        let container = try ModelContainer(for: PlannedCompetition.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private let day = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func addsTheCompetitionAsGoing() throws {
        let context = try context()
        PlannedCompetition.goingFromKSIS(name: "Optima dance cup", venue: "Košice", date: day, categories: ["Dospelí D ŠTT"],
                                         propId: 2277, context: context)
        let saved = try context.fetch(FetchDescriptor<PlannedCompetition>())
        #expect(saved.count == 1)
        #expect(saved.first?.intent == .going)
        #expect(saved.first?.ksisPropId == 2277)
        #expect(saved.first?.targetCategories == ["Dospelí D ŠTT"])
    }

    @Test func aCompetitionAddedByHandIsLinkedNotDoubled() throws {
        let context = try context()
        let byHand = PlannedCompetition(name: "Optima dance cup", city: "Košice", date: day)
        byHand.targetCategories = ["Štandard"]
        context.insert(byHand)
        try context.save()

        PlannedCompetition.goingFromKSIS(name: "Optima dance cup", venue: "OC Optima", date: day, categories: [], propId: 2277, context: context)

        let saved = try context.fetch(FetchDescriptor<PlannedCompetition>())
        #expect(saved.count == 1)
        #expect(saved.first?.ksisPropId == 2277)
        #expect(saved.first?.intent == .going)
        #expect(saved.first?.targetCategories == ["Štandard"])
        #expect(saved.first?.city == "Košice")
    }
}

/// What KSIS changed about a competition the dancer said Idem to: a category gone from the list, the competition
/// cancelled, KSIS's own note.
@MainActor
struct KSISChangeTests {
    private func event(categories: [String], note: String? = nil, isCancelled: Bool = false) -> KSISEvent {
        KSISEvent(propId: 2277, name: "Optima dance cup", date: "2026-12-13", venue: "Košice", city: "Košice", organizer: "TC Meteor",
                  note: note, categories: categories, kind: .competition, isCancelled: isCancelled, registered: nil, hasTimetable: false)
    }

    private func plan(_ categories: [String], intent: CompetitionIntent = .going, daysAhead: Int = 10) -> PlannedCompetition {
        let plan = PlannedCompetition(name: "Optima dance cup", city: "Košice", date: Date().addingTimeInterval(Double(daysAhead) * 86_400))
        plan.targetCategories = categories
        plan.intent = intent
        return plan
    }

    @Test func aCategoryKSISNoLongerListsIsMissing() {
        let listed = event(categories: ["Dospelí C ŠTT", "Dospelí C LAT"])
        #expect(listed.missing(from: ["Dospelí D ŠTT", "Dospelí D LAT"]) == ["Dospelí D ŠTT", "Dospelí D LAT"])
        #expect(listed.missing(from: ["Dospelí C ŠTT", "Dospelí D LAT"]) == ["Dospelí D LAT"])
    }

    @Test func namesAreComparedWithoutDiacriticsOrCase() {
        #expect(event(categories: ["Dospelí C ŠTT"]).missing(from: ["dospeli c stt"]).isEmpty)
    }

    @Test func thePlannersOwnWordsAreNeverCompared() {
        #expect(event(categories: []).missing(from: ["Štandard", "Latina"]).isEmpty)
    }

    @Test func anOlderFreeTextIsReadAsTheNamesItHolds() {
        #expect(event(categories: ["Dospelí C ŠTT"]).missing(from: ["Dospelí C ŠTT, Dospelí D LAT"]) == ["Dospelí D LAT"])
    }

    @Test func aCancelledCompetitionIsSaidOnce() {
        let lines = KSISChangeNotice.lines(for: plan(["Dospelí D ŠTT"]), event: event(categories: [], isCancelled: true))
        #expect(lines == ["KSIS súťaž zrušil."])
    }

    @Test func aGoneCategoryIsNamed() {
        let lines = KSISChangeNotice.lines(for: plan(["Dospelí D ŠTT", "Dospelí D LAT"]), event: event(categories: ["Dospelí D LAT"]))
        #expect(lines == ["V KSIS už nie je tvoja kategória: Dospelí D ŠTT."])
    }

    @Test func theNoteOfKSISComesAfterTheRest() {
        let note = "Pozor zmena !!! Zmena harmonogramu"
        #expect(KSISChangeNotice.lines(for: plan(["Dospelí D ŠTT"]), event: event(categories: ["Dospelí D ŠTT"], note: note)) == [note])
        let both = KSISChangeNotice.lines(for: plan(["Dospelí D ŠTT"]), event: event(categories: [], note: note))
        #expect(both == ["V KSIS už nie je tvoja kategória: Dospelí D ŠTT.", note])
    }

    @Test func nothingChangedSaysNothing() {
        #expect(KSISChangeNotice.lines(for: plan(["Dospelí D ŠTT"]), event: event(categories: ["Dospelí D ŠTT"])).isEmpty)
        #expect(KSISChangeNotice.lines(for: plan([]), event: event(categories: ["Dospelí D ŠTT"])).isEmpty)
    }

    @Test func aCompetitionTurnedDownDancedOrUnknownSaysNothing() {
        let gone = event(categories: [], isCancelled: true)
        #expect(KSISChangeNotice.lines(for: plan(["Dospelí D ŠTT"], intent: .declined), event: gone).isEmpty)
        #expect(KSISChangeNotice.lines(for: plan(["Dospelí D ŠTT"], daysAhead: -3), event: gone).isEmpty)
        #expect(KSISChangeNotice.lines(for: plan(["Dospelí D ŠTT"]), event: nil).isEmpty)
    }

    @Test func theDayOfTheCompetitionStillWarns() {
        let lines = KSISChangeNotice.lines(for: plan(["Dospelí D ŠTT"], daysAhead: 0), event: event(categories: [], isCancelled: true))
        #expect(lines == ["KSIS súťaž zrušil."])
    }
}

/// The part of KSIS a page belongs to, for the tabs above it.
struct KSISTabTests {
    @Test(arguments: [
        ("https://szts.ksis.eu/menu.php?akcia=S", KSISTab.results),
        ("https://szts.ksis.eu/sutaz.php?sutaz_id=12094", .results),
        ("https://szts.ksis.eu/hodnot_sut.php?sutaz_id=12094", .results),
        ("https://szts.ksis.eu/menu.php?akcia=KS&dt_od=01.11.2026", .calendar),
        ("https://szts.ksis.eu/zoznam_prihl.php?id_prop=2271", .calendar),
        ("https://szts.ksis.eu/slp_poradie.php?rok=2026", .cup),
        ("https://szts.ksis.eu/slp_msr.php", .cup),
        ("https://szts.ksis.eu/menu.php?akcia=CZP&hladany_text=Kalina", .couples),
        ("https://szts.ksis.eu/par.php?id=18967", .couples),
    ])
    func aPageLightsUpItsPart(url: String, tab: KSISTab) {
        #expect(KSISTab(url: URL(string: url)) == tab)
    }

    @Test func aPageOfNoPartLightsUpNothing() {
        #expect(KSISTab(url: URL(string: "https://szts.ksis.eu/menu.php?akcia=K")) == nil)
        #expect(KSISTab(url: URL(string: "https://szts.ksis.eu/")) == nil)
    }
}

/// A dancer's couples are told apart by the partner's name, written the way KSIS writes it.
struct PartnerNameTests {
    private func couple(_ names: String) throws -> UserCouple {
        let json: [String: Any] = ["id": UUID().uuidString, "partner_names": names]
        return try JSONDecoder().decode(UserCouple.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test func thePartnerIsTheOtherDancer() throws {
        let pair = try couple("Kalina Jakub - Kissová Nikoletta")
        #expect(pair.partnerName(besides: "Kalina Jakub") == "Kissová Nikoletta")
        #expect(pair.partnerName(besides: "KISSOVA Nikoletta") == "Kalina Jakub")
    }

    @Test func anUnknownDancerKeepsTheWholeCouple() throws {
        let pair = try couple("Kalina Jakub - Kissová Nikoletta")
        #expect(pair.partnerName(besides: nil) == "Kalina Jakub & Kissová Nikoletta")
        #expect(pair.partnerName(besides: "Niekto Iný") == "Kalina Jakub & Kissová Nikoletta")
    }
}
