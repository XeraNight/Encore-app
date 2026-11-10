import Testing
import Foundation
@testable import Encore

/// Štandard and Latina count only published marks ("X" and "."), per dance and per season (September to August).
@MainActor
struct MySeasonTests {

    /// One result with a crosses round (W: 2 of 3, Q: 1 of 3) and optionally a final.
    private func result(date: String, discipline: String = "STT", place: Int = 3, withFinal: Bool = false) throws -> CompetitionResult {
        let final = withFinal ? """
        ,{"round":"Finále","kind":"final","dances":[
          {"dance":"WALTZ","marks":[{"letter":"A","mark":"2"},{"letter":"B","mark":"4"}],"crosses":null},
          {"dance":"QUICKSTEP","marks":[{"letter":"A","mark":"1"},{"letter":"B","mark":"3"}],"crosses":null}],
          "sum":10,"couplesInRound":6}
        """ : ""
        // D judges only the final, E is a judge KSIS does not publish.
        let finalJudge = withFinal ? #",{"letter":"D","name":"Rozhodca D","city":null,"hidden":false}"# : ""
        let json = """
        {"id":"\(UUID().uuidString)","sutaz_id":1,"couple_id":7,"event_name":"GP","category_name":"Dospelí D",
         "discipline":"\(discipline)","date":"\(date)","couple_count":12,"placement_text":"\(place).","placement":\(place),
         "points_earned":0,
         "judges":[{"letter":"A","name":"Rozhodca A","city":"Košice","hidden":false},
                   {"letter":"B","name":"Rozhodca B","city":null,"hidden":false},
                   {"letter":"C","name":"Rozhodca C","city":null,"hidden":false},
                   {"letter":"E","name":null,"city":null,"hidden":true}\(finalJudge)],
         "rounds":[{"round":"1.kolo","kind":"crosses","dances":[
           {"dance":"WALTZ","marks":[{"letter":"A","mark":"X"},{"letter":"B","mark":"X"},{"letter":"C","mark":"."}],"crosses":2},
           {"dance":"QUICKSTEP","marks":[{"letter":"A","mark":"."},{"letter":"B","mark":"X"},{"letter":"C","mark":"."}],"crosses":1}],
           "sum":3,"couplesInRound":12}\(final)]}
        """
        return try JSONDecoder().decode(CompetitionResult.self, from: Data(json.utf8))
    }

    @Test func countsCrossesPerDanceFromPublishedMarks() throws {
        let stats = SeasonStats(results: [try result(date: "2026-10-03"), try result(date: "2026-11-14")], seasonStartYear: 2026)
        let standard = try #require(stats.disciplines.first)
        #expect(standard.dances.map(\.dance) == ["Waltz", "Quickstep"])
        #expect(standard.dances.map(\.crosses) == [4, 2])
        #expect(standard.dances.map(\.marks) == [6, 6])
        #expect(standard.weakest?.dance == "Quickstep")
        #expect(stats.timeline.compactMap(\.rate) == [0.5, 0.5])
    }

    @Test func seasonRunsFromSeptemberToAugust() throws {
        let results = [try result(date: "2026-08-30"), try result(date: "2026-09-01"), try result(date: "2027-08-31")]
        #expect(SeasonStats(results: results, seasonStartYear: 2026).competitions == 2)
        #expect(SeasonStats(results: results, seasonStartYear: 2025).competitions == 1)
        #expect(SeasonStats.seasons(in: results) == [2026, 2025])
    }

    @Test func finalsAveragePlacingsAndBestPlace() throws {
        let stats = SeasonStats(results: [try result(date: "2026-10-03", place: 5), try result(date: "2026-11-14", place: 2, withFinal: true)],
                                seasonStartYear: 2026)
        #expect(stats.finals == 1)
        #expect(stats.bestPlaceLine == "2. z 12")
        let finals = try #require(stats.disciplines.first?.finals)
        #expect(finals.map(\.dance) == ["Waltz", "Quickstep"])
        #expect(finals.map(\.average) == [3, 2])
    }

    @Test func everySeasonWhenNoneIsGiven() throws {
        let results = [try result(date: "2025-10-03"), try result(date: "2026-11-14")]
        #expect(SeasonStats(results: results, seasonStartYear: nil).competitions == 2)
        #expect(SeasonStats.seasonTitle(2026) == "2026/27")
    }

    @Test func everyJudgeWhoMarkedTheCoupleByHowOften() throws {
        let judges = JudgeStat.all(in: [try result(date: "2026-10-03"), try result(date: "2026-11-14", withFinal: true)])
        // D is listed but gave the couple no mark; E is hidden by KSIS.
        #expect(judges.map(\.name) == ["Rozhodca A", "Rozhodca B", "Rozhodca C"])
        #expect(judges.map(\.competitions.count) == [2, 2, 2])
        let withFinal = try #require(judges.first?.competitions.first { !$0.finalPlaces.isEmpty })
        #expect(withFinal.finalPlaces == [2, 1])
        #expect(withFinal.finalAverage == 1.5)
        #expect(judges.map { $0.competitions.map(\.crosses).reduce(0, +) } == [2, 4, 0])
        #expect(judges.first?.city == "Košice")
    }

    @Test func shadowJuryIsNeverAJudge() throws {
        let json = """
        {"id":"\(UUID().uuidString)","sutaz_id":1,"couple_id":7,"event_name":"GP","category_name":"Dospelí D",
         "discipline":"STT","date":"2026-10-03","couple_count":12,"placement_text":"3.","placement":3,"points_earned":0,
         "judges":[{"letter":"A","name":"Rozhodca A","city":null,"hidden":false},
                   {"letter":"A","name":"Tieň A","city":null,"hidden":false,"shadow":true}],
         "rounds":[{"round":"1.kolo","kind":"crosses","dances":[
           {"dance":"WALTZ","marks":[{"letter":"A","mark":"X"}],"crosses":1}],"sum":1,"couplesInRound":12}]}
        """
        let result = try JSONDecoder().decode(CompetitionResult.self, from: Data(json.utf8))
        #expect(JudgeStat.all(in: [result]).map(\.name) == ["Rozhodca A"])
        #expect(result.judges?.map(\.id) == ["A", "shadow-A"])
    }

    @Test func oneCoupleUnderTwoKSISIds() throws {
        func couple(_ names: String) throws -> UserCouple {
            try JSONDecoder().decode(UserCouple.self, from: Data(#"{"id":"\#(UUID().uuidString)","partner_names":"\#(names)"}"#.utf8))
        }
        let saved = try couple("Kalina Jakub - Kissova Nikoletta")
        #expect(saved.sameCoupleKey == (try couple("Jakub Kalina - Nikoletta Kissová")).sameCoupleKey)
        #expect(saved.sameCoupleKey != (try couple("Jakub Kalina - Beata Mockova")).sameCoupleKey)
    }

    @Test func mapsKSISDanceNames() {
        #expect(DanceNames.stored(fromKSIS: "VIENNESE WALTZ") == "Viennese Waltz")
        #expect(DanceNames.stored(fromKSIS: "SLOWFOX") == "Slowfoxtrot")
        #expect(DanceNames.stored(fromKSIS: "CHA-CHA-CHA") == "Cha-Cha-Cha")
        #expect(DanceNames.stored(fromKSIS: "PASO DOBLE") == "Paso Doble")
        #expect(DanceNames.stored(fromKSIS: "POLKA") == "POLKA")
    }
}
