import Testing
import SwiftData
import Foundation
@testable import Encore

/// Súťaže as a careless, hurried or unlucky person meets it: broken or odd data from the server, odd names, dates at
/// the edge of a season, two competitions on one day, a robot page, a megabyte of nonsense. Each test is one thing that
/// could happen; the list is kept in docs/EDGE_CASES_PROFIL.md next to the cases that only an iPhone can show.
@MainActor
struct SutazeEdgeCaseTests {

    // MARK: Helpers
    private func resultJSON(id: String = UUID().uuidString, date: String = "2026-10-03", place: String = "3.", placement: String = "3",
                            count: Int = 12, extra: String = "") -> String {
        """
        {"id":"\(id)","sutaz_id":1,"couple_id":7,"event_name":"GP","category_name":"Dospelí D","discipline":"STT",
         "date":"\(date)","couple_count":\(count),"placement_text":"\(place)","placement":\(placement),"points_earned":0\(extra)}
        """
    }

    private func decode(_ json: String) throws -> CompetitionResult {
        try JSONDecoder().decode(CompetitionResult.self, from: Data(json.utf8))
    }

    private func couple(names: String?, pair: Int? = nil, id: String = UUID().uuidString) throws -> UserCouple {
        let nameField = names.map { ",\"partner_names\":\"\($0)\"" } ?? ""
        let pairField = pair.map { ",\"pair_number\":\($0)" } ?? ""
        return try JSONDecoder().decode(UserCouple.self, from: Data("{\"id\":\"\(id)\"\(nameField)\(pairField)}".utf8))
    }

    private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int, hour: Int = 12) -> Date {
        PlannerCalendar.calendar.date(from: DateComponents(year: year, month: month, day: dayOfMonth, hour: hour)) ?? Date()
    }

    /// The container goes with its context: a context whose container was freed stops the whole test run.
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([PlannedCompetition.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return (container, container.mainContext)
    }

    // MARK: Data from the server that is not as expected
    @Test func marksThatCannotBeReadDoNotHideTheResult() throws {
        let broken = try decode(resultJSON(extra: #","rounds":[{"round":1}],"judges":"oops""#))
        #expect(broken.rounds == nil)
        #expect(broken.judges == nil)
        #expect(broken.placeLine == "3. z 12")
    }

    @Test func nullMarksAndJudgesAreSimplyNone() throws {
        let plain = try decode(resultJSON(extra: #","rounds":null,"judges":null"#))
        #expect(plain.rounds == nil && plain.judges == nil)
    }

    @Test func unknownFieldsFromANewerServerAreIgnored() throws {
        let newer = try decode(resultJSON(extra: #","video_url":"x","scores":{"a":1}"#))
        #expect(newer.sutazId == 1)
    }

    @Test func oneUnreadableRowDoesNotHideTheOthers() throws {
        let good1 = resultJSON(), good2 = resultJSON(date: "2026-11-14")
        let bad = #"{"sutaz_id":"not a number"}"#
        let list = try JSONDecoder().decode(LossyList<CompetitionResult>.self, from: Data("[\(good1),\(bad),\(good2),42,null]".utf8))
        #expect(list.elements.count == 2)
        #expect(list.skipped == 3)
    }

    @Test func anEmptyListIsAnEmptyList() throws {
        let list = try JSONDecoder().decode(LossyList<CompetitionResult>.self, from: Data("[]".utf8))
        #expect(list.elements.isEmpty && list.skipped == 0)
    }

    @Test func placeReadsSensiblyWhateverKSISSent() throws {
        #expect(try decode(resultJSON(place: "", placement: "null")).placeLine == "– z 12")
        #expect(try decode(resultJSON(place: "12. – 13.", placement: "12", count: 16)).placeLine == "12. – 13. z 16")
        #expect(try decode(resultJSON(place: "1.", placement: "1", count: 0)).placeLine == "1.")
        #expect(try decode(resultJSON(place: "", placement: "4", count: 10)).placeLine == "4. z 10")
        #expect(try decode(resultJSON(place: "", placement: "null", count: 0)).placeLine == "–")
    }

    @Test func aDateThatDoesNotExistHasNoDate() throws {
        #expect(try decode(resultJSON(date: "2026-13-45")).dateValue == nil)
        #expect(try decode(resultJSON(date: "")).dateValue == nil)
        #expect(try decode(resultJSON(date: "7. 11. 2026")).dateValue == nil)
        #expect(try decode(resultJSON(date: "2026-11-07")).dateValue != nil)
    }

    @Test func aResultWithoutADateIsLeftOutOfSeasonsAndTimelines() throws {
        let results = [try decode(resultJSON(date: "garbage")), try decode(resultJSON(date: "2026-10-03"))]
        #expect(SeasonStats.seasons(in: results) == [2026])
        let stats = SeasonStats(results: results, seasonStartYear: 2026)
        #expect(stats.timeline.count == 1)
    }

    @Test func aMissingRequiredFieldIsAnErrorNotACrash() {
        #expect(throws: (any Error).self) { try self.decode(#"{"id":"\#(UUID().uuidString)"}"#) }
    }

    // MARK: Couples and names
    @Test func theSameCoupleIsRecognisedThroughExtraSpacesAndOrder() throws {
        let a = try couple(names: "Kalina Jakub - Kissova Nikoletta")
        let b = try couple(names: "  Jakub   Kalina  -  Nikoletta Kissová ")
        let c = try couple(names: "KALINA JAKUB - KISSOVÁ NIKOLETTA")
        #expect(a.sameCoupleKey == b.sameCoupleKey)
        #expect(a.sameCoupleKey == c.sameCoupleKey)
        // KSIS always writes the partner first: the same two names with the sides swapped are another record.
        #expect(a.sameCoupleKey != (try couple(names: "Kissova Nikoletta - Kalina Jakub")).sameCoupleKey)
    }

    @Test func coupleWithoutNamesIsOnlyItself() throws {
        let one = try couple(names: nil), two = try couple(names: "")
        #expect(one.sameCoupleKey != two.sameCoupleKey)
        #expect(one.sameCoupleKey == one.sameCoupleKey)
    }

    @Test func coupleTitleNeverIsEmpty() throws {
        #expect(try couple(names: nil).title == "Pár")
        #expect(try couple(names: "", pair: 12).title == "Pár 12")
        #expect(try couple(names: "A B - C D").title == "A B & C D")
    }

    @Test func thePartnerIsTheOtherName() throws {
        let pair = try couple(names: "Kalina Jakub - Kissová Nikoletta")
        #expect(pair.partnerName(besides: "kalina jakub") == "Kissová Nikoletta")
        #expect(pair.partnerName(besides: nil) == pair.title)
        #expect(pair.partnerName(besides: "Somebody Else") == pair.title)
        #expect(try couple(names: "Same - Same").partnerName(besides: "Same") == "Same & Same")
    }

    @Test func aCoupleWithNoStandingsShowsNothingInsteadOfDashes() throws {
        #expect(try couple(names: "A - B").standingsLine == "")
    }

    @Test func aCoupleMissingAFlagCountsAsCurrent() throws {
        #expect(try couple(names: "A - B").isCurrent)
    }

    // MARK: Addresses and search texts
    @Test func nameWithSpecialCharactersTravelsIntactInTheSearchAddress() throws {
        for text in ["Šebo & Co?#", "Ľ Ž / \\ \"quote\"", "a=b&c=d", "Ďurčová Mária", "  padded  "] {
            let url = try #require(KSISBrowserView.couplesURL(surname: text))
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let sent = items.first { $0.name == "hladany_text" }?.value
            #expect(sent == text.trimmingCharacters(in: .whitespaces), "\(text)")
            #expect(url.host == KSISBrowserView.host)
        }
    }

    @Test func aNumberSearchGoesToTheNumberFieldAndAnythingElseToTheName() throws {
        let number = try #require(KSISBrowserView.membersSearchURL(for: "95397"))
        let items = URLComponents(url: number, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "cis_pr" }?.value == "95397")
        #expect(items.first { $0.name == "hladany_text" }?.value == "")
        let mixed = try #require(KSISBrowserView.membersSearchURL(for: "95397a"))
        let mixedItems = URLComponents(url: mixed, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(mixedItems.first { $0.name == "hladany_text" }?.value == "95397a")
    }

    @Test func anEmptySearchOpensThePlainPageNotAnEmptyQuery() throws {
        let url = try #require(KSISBrowserView.membersSearchURL(for: "   "))
        #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains { $0.name == "hladany_text" } != true)
    }

    @Test func pairNumbersKeepTheirFiveDigits() throws {
        #expect(KSISBrowserView.coupleDetail(5)?.absoluteString.hasSuffix("cp=00005") == true)
        #expect(KSISBrowserView.coupleDetail(95397)?.absoluteString.hasSuffix("cp=95397") == true)
        #expect(KSISBrowserView.coupleDetail(123456)?.absoluteString.hasSuffix("cp=123456") == true)
    }

    @Test func surnameIsTheFirstWordWhateverTheSpaces() {
        #expect(KSISBrowserView.surname(of: "Kalina Jakub") == "Kalina")
        #expect(KSISBrowserView.surname(of: "   Kalina    Jakub") == "Kalina")
        #expect(KSISBrowserView.surname(of: "Kalina") == "Kalina")
        #expect(KSISBrowserView.surname(of: "").isEmpty)
    }

    @Test func nameSearchEncodesWhatTheDancerTyped() throws {
        let url = try #require(KSISBrowserView.nameSearchURL("Jakub Kalina & Niky ?x=1"))
        let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value
        #expect(value == "Jakub Kalina & Niky ?x=1")
    }

    // MARK: Seasons at their edges
    @Test func theSeasonTurnsOverOnTheFirstOfSeptember() {
        #expect(SeasonStats.seasonStartYear(of: day(2026, 8, 31, hour: 23)) == 2025)
        #expect(SeasonStats.seasonStartYear(of: day(2026, 9, 1, hour: 0)) == 2026)
        #expect(SeasonStats.seasonStartYear(of: day(2026, 12, 31, hour: 23)) == 2026)
        #expect(SeasonStats.seasonStartYear(of: day(2027, 1, 1, hour: 0)) == 2026)
        #expect(SeasonStats.seasonStartYear(of: day(2028, 2, 29)) == 2027)
    }

    @Test func seasonTitlesNeverBreak() {
        #expect(SeasonStats.seasonTitle(2026) == "2026/27")
        #expect(SeasonStats.seasonTitle(2099) == "2099/00")
        #expect(SeasonStats.seasonTitle(2009) == "2009/10")
    }

    @Test func noResultsMeansAnEmptySeasonNotACrash() {
        #expect(SeasonStats.seasons(in: []).isEmpty)
        let stats = SeasonStats(results: [], seasonStartYear: nil)
        #expect(stats.competitions == 0 && !stats.hasCrosses && stats.bestPlaceLine == nil && stats.timeline.isEmpty)
    }

    @Test func crossesWrittenOddlyAreCountedOnlyWhenTheyAreCrosses() throws {
        let marks = #"[{"letter":"A","mark":" x "},{"letter":"B","mark":"?"},{"letter":"C","mark":""},{"letter":"D","mark":"."},{"letter":"E","mark":"XX"}]"#
        let json = resultJSON(extra: #","rounds":[{"round":"1.kolo","kind":"crosses","dances":[{"dance":"WALTZ","marks":\#(marks),"crosses":1}],"sum":1,"couplesInRound":12}]"#)
        let stats = SeasonStats(results: [try decode(json)], seasonStartYear: 2026)
        let waltz = try #require(stats.disciplines.first?.dances.first)
        #expect(waltz.crosses == 1)
        #expect(waltz.marks == 2)
    }

    // MARK: Competitions in the plan and the results of their day
    @Test func twoResultsOnTheSameDayBothBelongToThatDay() throws {
        let competition = PlannedCompetition(name: "GP", city: "Košice", date: day(2026, 11, 7, hour: 9))
        let results = [try decode(resultJSON(date: "2026-11-07")), try decode(resultJSON(date: "2026-11-07")), try decode(resultJSON(date: "2026-11-08"))]
        #expect(competition.dancedResults(in: results).count == 2)
    }

    @Test func aDayWithoutResultsHasNoPlaceChip() throws {
        let competition = PlannedCompetition(name: "GP", city: "", date: day(2026, 11, 7))
        #expect(competition.dancedPlaceLine(in: []) == nil)
        #expect(competition.dancedPlaceLine(in: [try decode(resultJSON(date: "2026-11-09"))]) == nil)
    }

    @Test func theBestPlaceOfTheDayWins() throws {
        let competition = PlannedCompetition(name: "GP", city: "", date: day(2026, 11, 7))
        let results = [try decode(resultJSON(date: "2026-11-07", place: "5.", placement: "5")),
                       try decode(resultJSON(date: "2026-11-07", place: "2.", placement: "2")),
                       try decode(resultJSON(date: "2026-11-07", place: "", placement: "null"))]
        #expect(competition.dancedPlaceLine(in: results) == "2. z 12")
    }

    @Test func aCompetitionLateInTheEveningStillMatchesItsDay() throws {
        let competition = PlannedCompetition(name: "GP", city: "", date: day(2026, 11, 7, hour: 23))
        #expect(competition.dancedResults(in: [try decode(resultJSON(date: "2026-11-07"))]).count == 1)
        let early = PlannedCompetition(name: "GP", city: "", date: day(2026, 11, 7, hour: 0))
        #expect(early.dancedResults(in: [try decode(resultJSON(date: "2026-11-07"))]).count == 1)
    }

    @Test func linkingOnlyTouchesPastCompetitionsWithoutALink() throws {
        let (store, context) = try makeContext()
        defer { withExtendedLifetime(store) {} }
        let past = PlannedCompetition(name: "Past", city: "", date: day(2020, 1, 11))
        let linked = PlannedCompetition(name: "Linked", city: "", date: day(2020, 1, 11))
        linked.ksisCompetitionId = "999"
        let future = PlannedCompetition(name: "Future", city: "", date: day(2099, 1, 11))
        [past, linked, future].forEach(context.insert)
        let results = [try decode(resultJSON(date: "2020-01-11")), try decode(resultJSON(date: "2099-01-11"))]
        PlannedCompetition.linkDanced([past, linked, future], to: results, context: context)
        #expect(past.ksisCompetitionId == "1")
        #expect(linked.ksisCompetitionId == "999")
        #expect(future.ksisCompetitionId == nil)
        PlannedCompetition.linkDanced([past, linked, future], to: results, context: context)
        #expect(past.ksisCompetitionId == "1")
    }

    @Test func aPlannedCompetitionWithAnUnknownIntentStillOpens() {
        let competition = PlannedCompetition(name: "GP", city: "", date: Date())
        competition.intentRaw = "nonsense from a newer version"
        #expect(competition.intent == .interested)
    }

    // MARK: Reading KSIS when the world is odd
    @Test func aCallRefusedByThePlatformIsKnownAsALimit() {
        guard case .server(let code, let message) = EdgeFunctionClient.failure(status: 429, data: Data()) else {
            Issue.record("a refused call is a server failure")
            return
        }
        #expect(code == "rate_limited")
        #expect(message == nil)
        guard case .server(let own, let text) = EdgeFunctionClient.failure(
            status: 422, data: Data(#"{"error":"parse_failed","message":"Zle."}"#.utf8)) else {
            Issue.record("an error answer of ours is a server failure")
            return
        }
        #expect(own == "parse_failed")
        #expect(text == "Zle.")
        guard case .server(let none, _) = EdgeFunctionClient.failure(status: 502, data: Data("<html>".utf8)) else {
            Issue.record("a bad gateway is a server failure")
            return
        }
        #expect(none == nil)
    }

    @Test func theCupYearIsTheGregorianOneWhateverTheCalendarOfThePhone() throws {
        let date = try #require(DateComponents(calendar: Calendar(identifier: .gregorian), year: 2026, month: 11, day: 16, hour: 12).date)
        #expect(SlovakCup.currentYear(date) == 2026)
        // What Calendar.current would give on a phone set to a Buddhist calendar.
        #expect(Calendar(identifier: .buddhist).component(.year, from: date) == 2569)
        let url = try #require(SlovakCup.standingsURL(year: SlovakCup.currentYear(date), group: .adults, discipline: .standard))
        #expect(url.absoluteString.contains("rok=2026"))
    }

    // MARK: What went wrong in an update
    @Test func theLastLineNamesWhatFailedEachOnceAndAtMostTwo() {
        var problems = KSISUpdateProblems()
        #expect(problems.sentence == nil)
        problems.note("Prvá.")
        problems.note("Prvá.")
        problems.note("Druhá.")
        problems.note("Tretia.")
        #expect(problems.sentence == "Nepodarilo sa: Prvá. Druhá.")
    }

    // MARK: The KSIS calendar page
    @Test func nothingAtAllIsNotACalendar() {
        #expect(throws: KSISCalendarPage.Failure.layoutChanged) { try KSISCalendarPage.parse("") }
        #expect(throws: KSISCalendarPage.Failure.layoutChanged) { try KSISCalendarPage.parse("<html></html>") }
    }

    @Test func aRobotCheckIsNeverACalendarInAnyCase() {
        #expect(throws: KSISCalendarPage.Failure.challenge) { try KSISCalendarPage.parse("<TITLE>Just A Moment...</TITLE>") }
        #expect(throws: KSISCalendarPage.Failure.challenge) { try KSISCalendarPage.parse("PREBIEHA BEZPEČNOSTNÉ OVERENIE") }
    }

    @Test(.timeLimit(.minutes(1))) func aMegabyteOfNonsenseIsAnsweredQuickly() {
        let nonsense = String(repeating: "<tr><td valign=\"top\"><strong>", count: 20_000) + String(repeating: "x", count: 600_000)
        let started = ContinuousClock.now
        _ = try? KSISCalendarPage.parse(nonsense)
        _ = try? KSISCalendarPage.parse("name=\"vekova_ktg\"" + nonsense)
        #expect(ContinuousClock.now - started < .seconds(10))
    }

    @Test func aHugeSumFromASavedPageIsShownAndNeverStopsTheApp() {
        func round(sum: Double) -> KSISRound {
            KSISRound(round: "Finále", kind: "crosses", dances: [], sum: sum, place: nil, advanced: nil, couplesInRound: 6,
                      advancedCount: nil, visibleCrosses: nil, hiddenCrosses: nil)
        }
        #expect(round(sum: 28).sumText == "28")
        #expect(!round(sum: 1e30).sumText.isEmpty)
        #expect(!round(sum: .infinity).sumText.isEmpty)
        #expect(!round(sum: .nan).sumText.isEmpty)
    }

    @Test func aHalfLoadedPageNeverCrashesAndIsNeverAHalfTrueCalendar() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let html = try String(contentsOf: root.appending(path: "fixtures/ksis/calendar.html"), encoding: .utf8)
        for fraction in [0.1, 0.33, 0.5, 0.9] {
            let cut = String(html.prefix(Int(Double(html.count) * fraction)))
            if let events = try? KSISCalendarPage.parse(cut) {
                // A page cut inside a row cannot give an event with missing parts.
                #expect(events.allSatisfy { !$0.name.isEmpty && !$0.date.isEmpty })
            }
        }
    }

    @Test func theSamePageTwiceDoesNotCrash() throws {
        let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let html = try String(contentsOf: root.appending(path: "fixtures/ksis/calendar.html"), encoding: .utf8)
        let events = try KSISCalendarPage.parse(html + html)
        // A line listed twice is one competition: the list is keyed by id.
        #expect(events.count == 46)
        #expect(Set(events.map(\.id)).count == events.count)
    }
}
