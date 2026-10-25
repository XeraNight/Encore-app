import Foundation
import Testing
@testable import Encore

@MainActor
struct SlovakCupTests {
    private func standings(_ totals: [Int], places: [String]? = nil, category: String = "Dospelí Štandard") throws -> SlovakCupStandings {
        let entries = totals.enumerated().map { index, total in
            let place = places?[index] ?? "\(index + 1)."
            return """
            {"place":{"from":\(Int(place.prefix(while: \.isNumber)) ?? index + 1),"to":\(index + 1),"text":"\(place)"},
             "parId":\(1000 + index),"partner":"Pár\(index) Adam","partnerka":"Pár\(index) Eva","club":"TK",
             "rounds":[{"place":null,"points":\(total)},null],"total":\(total)}
            """
        }
        let json = """
        {"year":2026,"category":"\(category)","countedRounds":4,
         "rounds":[{"sutazId":1,"venue":"Poprad","date":"2026-03-28"},{"sutazId":2,"venue":"Trenčín","date":"2026-05-02"}],
         "entries":[\(entries.joined(separator: ","))]}
        """
        return try JSONDecoder().decode(SlovakCupStandings.self, from: Data(json.utf8))
    }

    private func couple(id: Int?, names: String, age: String = "Dospelí", stt: String? = nil, lat: String? = nil) throws -> UserCouple {
        let idField = id.map { "\"couple_id\":\($0)," } ?? ""
        let classes = [stt.map { "\"stt_class\":\"\($0)\"," }, lat.map { "\"lat_class\":\"\($0)\"," }].compactMap { $0 }.joined()
        let json = "{\"id\":\"\(UUID().uuidString)\",\(idField)\(classes)\"partner_names\":\"\(names)\",\"age_category\":\"\(age)\"}"
        return try JSONDecoder().decode(UserCouple.self, from: Data(json.utf8))
    }

    @Test func onlyCouplesInTheCupSeeIt() throws {
        let adultsD = try couple(id: 1, names: "A - B", age: "Dospelí", stt: "D", lat: "D")
        let adultsAB = try couple(id: 2, names: "A - B", age: "Dospelí", stt: "A", lat: "C")
        let juniorsOne = try couple(id: 3, names: "A - B", age: "Juniori I", stt: "B", lat: "A")
        let juniorsTwo = try couple(id: 4, names: "A - B", age: "Juniori II", stt: "A", lat: "D")
        let seniors = try couple(id: 5, names: "A - B", age: "Seniori I", stt: "A", lat: "A")
        #expect(SlovakCup.disciplines(for: adultsD).isEmpty)
        #expect(SlovakCup.disciplines(for: adultsAB) == [.standard])
        #expect(SlovakCup.disciplines(for: juniorsOne) == [.standard])
        #expect(SlovakCup.disciplines(for: juniorsTwo) == [.standard, .latin])
        #expect(SlovakCup.disciplines(for: seniors).isEmpty)
    }

    @Test func juniorsAndAdultsDanceTheirOwnSeries() {
        #expect(SlovakCup.Group(ageCategory: "Juniori II") == .juniors)
        #expect(SlovakCup.Group(ageCategory: "Juniori Latin") == .juniors)
        #expect(SlovakCup.Group(ageCategory: "Dospelí") == .adults)
        #expect(SlovakCup.Group(ageCategory: "Mládež") == .adults)
        #expect(SlovakCup.Group(ageCategory: "Do 21") == .adults)
        #expect(SlovakCup.Group(ageCategory: "Seniori I") == nil)
        #expect(SlovakCup.Group(ageCategory: "Deti II") == nil)
    }

    @Test func theOfficialTableAddress() {
        let url = SlovakCup.standingsURL(year: 2026, group: .juniors, discipline: .latin)
        #expect(url?.absoluteString == "https://szts.ksis.eu/slp_poradie.php?rok=2026&druh=SLPJUN&s_l=L")
    }

    @Test func theCoupleIsFoundByItsIdOrByBothNames() throws {
        let table = try standings([90, 80, 70])
        let byId = try couple(id: 1001, names: "Iný - Pár")
        // Different case and diacritics, as KSIS and the app may write them.
        let byNames = try couple(id: nil, names: "PÁR2 ADAM - par2 eva")
        let stranger = try couple(id: nil, names: "Niekto - Iný")
        #expect(SlovakCup.entry(in: table, for: byId)?.parId == 1001)
        #expect(SlovakCup.entry(in: table, for: byNames)?.parId == 1002)
        #expect(SlovakCup.entry(in: table, for: stranger) == nil)
    }

    @Test func adultsSeeTheirPlaceAgainstTheClassPlaces() throws {
        let table = try standings([100, 90, 80, 70, 60, 50, 40, 30, 20, 10, 9, 8, 7])
        let sixth = try #require(table.entries.first { $0.parId == 1005 })
        let status = SlovakCup.status(of: sixth, in: table, group: .adults)
        #expect(status.total == 50)
        #expect(status.danced == 1)
        #expect(status.held == 2)
        let places = status.targets.map { $0.place }
        let reached = status.targets.allSatisfy { $0.reached }
        #expect(places == [8, 12, 20])
        #expect(reached)
    }

    @Test func juniorsSeeWhatIsMissingToBeAhead() throws {
        let table = try standings([100, 90, 80, 70, 60, 50, 40], category: "Juniori Štandard")
        let seventh = try #require(table.entries.first { $0.parId == 1006 })
        let status = SlovakCup.status(of: seventh, in: table, group: .juniors)
        // 3rd has 80 and 6th has 50: 41 and 11 points to get ahead of them; 24 places are more than the table has.
        let missing = status.targets.map { $0.missing }
        let reached = status.targets.map { $0.reached }
        #expect(missing == [41, 11, 0])
        #expect(reached == [false, false, true])
    }

    @Test func aSharedPlaceCountsFromItsFirstNumber() throws {
        let table = try standings([100, 90, 80, 70, 60, 50, 50, 40], places: ["1.", "2.", "3.", "4.", "5.", "6. - 7.", "6. - 7.", "8."],
                                  category: "Juniori Latin")
        let shared = try #require(table.entries.first { $0.parId == 1006 })
        let classB = SlovakCup.status(of: shared, in: table, group: .juniors).targets[1]
        #expect(classB.reached)
    }
}
