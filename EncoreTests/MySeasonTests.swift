import Testing
import Foundation
@testable import Encore

/// Moja sezóna counts only published marks ("X" and "."), per dance and per season (September to August).
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
        let json = """
        {"id":"\(UUID().uuidString)","sutaz_id":1,"couple_id":7,"event_name":"GP","category_name":"Dospelí D",
         "discipline":"\(discipline)","date":"\(date)","couple_count":12,"placement_text":"\(place).","placement":\(place),
         "points_earned":0,
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

    @Test func mapsKSISDanceNames() {
        #expect(DanceNames.stored(fromKSIS: "VIENNESE WALTZ") == "Viennese Waltz")
        #expect(DanceNames.stored(fromKSIS: "SLOWFOX") == "Slowfoxtrot")
        #expect(DanceNames.stored(fromKSIS: "CHA-CHA-CHA") == "Cha-Cha-Cha")
        #expect(DanceNames.stored(fromKSIS: "PASO DOBLE") == "Paso Doble")
        #expect(DanceNames.stored(fromKSIS: "POLKA") == "POLKA")
    }
}
