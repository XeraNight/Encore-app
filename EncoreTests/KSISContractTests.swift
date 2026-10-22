import Testing
import Foundation
@testable import Encore

/// The app must read exactly what `ksis-page` sends and what the diary stores. The marks reply below was
/// produced by the server's own readers from the anonymized fixture `fixtures/ksis/marks_12094.html`
/// (couple 18978): 28 = 24 published + 4 from the hidden judge D, 26 = 22 + 4, final 15 and 3rd place.
@MainActor
struct KSISContractTests {

    private static let marksReply = #"{"kind":"marks","competition":{"sutazId":12094,"eventName":"Košice Grand Prix 2026 - Parket B","category":"Dospelí D ŠTT","date":"2026-09-12","venue":"Spoločenský pavilón, Trieda SNP 61, Košice","couples":13,"advancement":[13,9,6]},"dances":["WALTZ","TANGO","VIENNESE WALTZ","QUICKSTEP"],"judges":[{"letter":"A","name":"Čemálu Dľomása","city":"Ukrajina","hidden":false},{"letter":"B","name":"Fimážie Gúmáťa","city":"Martin","hidden":false},{"letter":"C","name":"Hramágú Jimámá","city":"Prešov","hidden":false},{"letter":"D","name":null,"city":null,"hidden":true},{"letter":"E","name":"Komášte Lumány","city":"Bratislava","hidden":false},{"letter":"F","name":"Mámábá Němáhra","city":"Kežmarok","hidden":false},{"letter":"G","name":"Pománě Rímátu","city":"Poprad","hidden":false}],"startNumber":"61","rounds":[{"round":"1.kolo","kind":"crosses","dances":[{"dance":"WALTZ","marks":[{"letter":"A","name":"Čemálu Dľomása","mark":"X"},{"letter":"B","name":"Fimážie Gúmáťa","mark":"X"},{"letter":"C","name":"Hramágú Jimámá","mark":"X"},{"letter":"E","name":"Komášte Lumány","mark":"X"},{"letter":"F","name":"Mámábá Němáhra","mark":"X"},{"letter":"G","name":"Pománě Rímátu","mark":"X"}],"crosses":6},{"dance":"TANGO","marks":[{"letter":"A","name":"Čemálu Dľomása","mark":"X"},{"letter":"B","name":"Fimážie Gúmáťa","mark":"X"},{"letter":"C","name":"Hramágú Jimámá","mark":"X"},{"letter":"E","name":"Komášte Lumány","mark":"X"},{"letter":"F","name":"Mámábá Němáhra","mark":"X"},{"letter":"G","name":"Pománě Rímátu","mark":"X"}],"crosses":6},{"dance":"VIENNESE WALTZ","marks":[{"letter":"A","name":"Čemálu Dľomása","mark":"X"},{"letter":"B","name":"Fimážie Gúmáťa","mark":"X"},{"letter":"C","name":"Hramágú Jimámá","mark":"X"},{"letter":"E","name":"Komášte Lumány","mark":"X"},{"letter":"F","name":"Mámábá Němáhra","mark":"X"},{"letter":"G","name":"Pománě Rímátu","mark":"X"}],"crosses":6},{"dance":"QUICKSTEP","marks":[{"letter":"A","name":"Čemálu Dľomása","mark":"X"},{"letter":"B","name":"Fimážie Gúmáťa","mark":"X"},{"letter":"C","name":"Hramágú Jimámá","mark":"X"},{"letter":"E","name":"Komášte Lumány","mark":"X"},{"letter":"F","name":"Mámábá Němáhra","mark":"X"},{"letter":"G","name":"Pománě Rímátu","mark":"X"}],"crosses":6}],"sum":28,"place":{"from":1,"to":2,"text":"1 - 2"},"advanced":true,"couplesInRound":13,"advancedCount":9,"visibleCrosses":24,"hiddenCrosses":4},{"round":"Semifinále","kind":"crosses","dances":[{"dance":"WALTZ","marks":[{"letter":"A","name":"Čemálu Dľomása","mark":"."},{"letter":"B","name":"Fimážie Gúmáťa","mark":"X"},{"letter":"C","name":"Hramágú Jimámá","mark":"X"},{"letter":"E","name":"Komášte Lumány","mark":"X"},{"letter":"F","name":"Mámábá Němáhra","mark":"X"},{"letter":"G","name":"Pománě Rímátu","mark":"X"}],"crosses":5},{"dance":"TANGO","marks":[{"letter":"A","name":"Čemálu Dľomása","mark":"X"},{"letter":"B","name":"Fimážie Gúmáťa","mark":"X"},{"letter":"C","name":"Hramágú Jimámá","mark":"X"},{"letter":"E","name":"Komášte Lumány","mark":"X"},{"letter":"F","name":"Mámábá Němáhra","mark":"X"},{"letter":"G","name":"Pománě Rímátu","mark":"X"}],"crosses":6},{"dance":"VIENNESE WALTZ","marks":[{"letter":"A","name":"Čemálu Dľomása","mark":"X"},{"letter":"B","name":"Fimážie Gúmáťa","mark":"X"},{"letter":"C","name":"Hramágú Jimámá","mark":"X"},{"letter":"E","name":"Komášte Lumány","mark":"X"},{"letter":"F","name":"Mámábá Němáhra","mark":"X"},{"letter":"G","name":"Pománě Rímátu","mark":"X"}],"crosses":6},{"dance":"QUICKSTEP","marks":[{"letter":"A","name":"Čemálu Dľomása","mark":"X"},{"letter":"B","name":"Fimážie Gúmáťa","mark":"."},{"letter":"C","name":"Hramágú Jimámá","mark":"X"},{"letter":"E","name":"Komášte Lumány","mark":"X"},{"letter":"F","name":"Mámábá Němáhra","mark":"X"},{"letter":"G","name":"Pománě Rímátu","mark":"X"}],"crosses":5}],"sum":26,"place":{"from":1,"to":3,"text":"1 - 3"},"advanced":true,"couplesInRound":9,"advancedCount":6,"visibleCrosses":22,"hiddenCrosses":4},{"round":"Finále","kind":"final","dances":[{"dance":"WALTZ","marks":[{"letter":"A","name":"Čemálu Dľomása","mark":"3"},{"letter":"B","name":"Fimážie Gúmáťa","mark":"3"},{"letter":"C","name":"Hramágú Jimámá","mark":"1"},{"letter":"E","name":"Komášte Lumány","mark":"4"},{"letter":"F","name":"Mámábá Němáhra","mark":"2"},{"letter":"G","name":"Pománě Rímátu","mark":"6"}],"crosses":null},{"dance":"TANGO","marks":[{"letter":"A","name":"Čemálu Dľomása","mark":"1"},{"letter":"B","name":"Fimážie Gúmáťa","mark":"4"},{"letter":"C","name":"Hramágú Jimámá","mark":"4"},{"letter":"E","name":"Komášte Lumány","mark":"1"},{"letter":"F","name":"Mámábá Němáhra","mark":"3"},{"letter":"G","name":"Pománě Rímátu","mark":"3"}],"crosses":null},{"dance":"VIENNESE WALTZ","marks":[{"letter":"A","name":"Čemálu Dľomása","mark":"6"},{"letter":"B","name":"Fimážie Gúmáťa","mark":"3"},{"letter":"C","name":"Hramágú Jimámá","mark":"3"},{"letter":"E","name":"Komášte Lumány","mark":"5"},{"letter":"F","name":"Mámábá Němáhra","mark":"4"},{"letter":"G","name":"Pománě Rímátu","mark":"6"}],"crosses":null},{"dance":"QUICKSTEP","marks":[{"letter":"A","name":"Čemálu Dľomása","mark":"3"},{"letter":"B","name":"Fimážie Gúmáťa","mark":"6"},{"letter":"C","name":"Hramágú Jimámá","mark":"3"},{"letter":"E","name":"Komášte Lumány","mark":"5"},{"letter":"F","name":"Mámábá Němáhra","mark":"4"},{"letter":"G","name":"Pománě Rímátu","mark":"4"}],"crosses":null}],"sum":15,"place":{"from":3,"to":3,"text":"3"},"advanced":null,"couplesInRound":6,"advancedCount":null,"visibleCrosses":null,"hiddenCrosses":null}]}"#

    @Test func marksReplyFromTheServerIsReadCompletely() throws {
        let reply = try JSONDecoder().decode(KSISPageReply.self, from: Data(Self.marksReply.utf8))
        #expect(reply.kind == .marks)
        #expect(reply.competition?.sutazId == 12094)
        #expect(reply.competition?.advancement == [13, 9, 6])
        #expect(reply.judges?.map(\.letter) == ["A", "B", "C", "D", "E", "F", "G"])
        #expect(reply.judges?.filter(\.hidden).map(\.letter) == ["D"])

        let rounds = try #require(reply.rounds)
        #expect(rounds.map(\.round) == ["1.kolo", "Semifinále", "Finále"])

        let first = rounds[0]
        #expect(first.sumText == "28")
        #expect(first.visibleCrosses == 24)
        #expect(first.hiddenCrosses == 4)
        #expect(first.advanced == true)
        #expect(first.advancedCount == 9)
        #expect(first.place?.display == "1. – 2.")
        #expect(first.dances.first?.marks.map { $0.letter ?? "" } == ["A", "B", "C", "E", "F", "G"])

        let semi = rounds[1]
        #expect(semi.sumText == "26")
        #expect(semi.hiddenCrosses == 4)
        #expect(semi.dances[0].marks.first { $0.mark == "." }?.letter == "A")

        let final = rounds[2]
        #expect(final.isFinal)
        #expect(final.sumText == "15")
        #expect(final.place?.display == "3.")
        #expect(final.dances[0].marks.map(\.mark).joined() == "331426")
    }

    @Test func unknownKindIsReadAsUnsupported() throws {
        let reply = try JSONDecoder().decode(KSISPageReply.self, from: Data(#"{"kind":"something_new"}"#.utf8))
        #expect(reply.kind == .unsupported)
    }

    @Test func linkedCoupleRowShowsOnlyKSISNumbers() throws {
        let row = #"""
        {"id":"7b4c7a6e-4a7e-4a49-9c55-7e2a3a0c1d11","pair_number":95397,"couple_id":null,
         "partner_names":"Tanečný Adam - Tanečná Eva","club":"TK ELLEGANCE Košice","age_category":"Dospelí",
         "stt_class":"D","stt_points":89,"stt_finals":5,"stt_last_change":"2026-09-12",
         "lat_class":"D","lat_points":91,"lat_finals":5,"lat_last_change":"2026-09-12",
         "ksis_refreshed_at":"2026-10-09T08:15:00.123+00:00"}
        """#
        let couple = try JSONDecoder().decode(UserCouple.self, from: Data(row.utf8))
        #expect(couple.title == "Tanečný Adam & Tanečná Eva")
        #expect(couple.standingsLine == "ŠTT D · 89 b · 5 F · LAT D · 91 b · 5 F")
        #expect(couple.coupleId == nil)
    }

    @Test func storedResultWithRoundsIsRead() throws {
        let reply = try JSONDecoder().decode(KSISPageReply.self, from: Data(Self.marksReply.utf8))
        let rounds = String(decoding: try JSONEncoder().encode(reply.rounds), as: UTF8.self)
        let judges = String(decoding: try JSONEncoder().encode(reply.judges), as: UTF8.self)
        let row = """
        {"id":"0f9d2c3a-1b2c-4d5e-8f90-a1b2c3d4e5f6","sutaz_id":12094,"couple_id":18978,
         "event_name":"Košice Grand Prix 2026 - Parket B","category_name":"Dospelí D ŠTT","discipline":"STT",
         "date":"2026-09-12","couple_count":13,"placement_text":"3.","placement":3,"points_earned":18,
         "cumulative_stats":"89/5F","start_number":"61","rounds":\(rounds),"judges":\(judges)}
        """
        let result = try JSONDecoder().decode(CompetitionResult.self, from: Data(row.utf8))
        #expect(result.placeLine == "3. z 13")
        #expect(result.rounds?.count == 3)
        #expect(result.judges?.contains { $0.letter == "D" && $0.hidden } == true)
        #expect(result.disciplineTitle == "Štandard")
    }
}
