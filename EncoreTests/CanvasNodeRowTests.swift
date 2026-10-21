import Testing
import Foundation
@testable import Encore

/// What a figure row sends to and reads from `canvas_nodes`.
struct CanvasNodeRowTests {
    private func row(bars: Int?) -> DBCanvasNodeRow {
        DBCanvasNodeRow(id: UUID(), routine_id: UUID(), x: 1, y: 2, figure_name: "Whisk", rhythm: "1, 2, 3", notes: "",
                        video_path: nil, order_index: 0, transition_notes: "", bars: bars)
    }

    private func json(_ row: DBCanvasNodeRow) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(row)) as? [String: Any])
    }

    @Test func clearedBarsGoUpAsNull() throws {
        // Left out, the upload would not name the column and the server would keep the old bars.
        let sent = try json(row(bars: nil))
        #expect(sent.keys.contains("bars"))
        #expect(sent["bars"] is NSNull)
        #expect(try json(row(bars: 3))["bars"] as? Int == 3)
    }

    @Test func otherEmptyFieldsStayOutAsBefore() throws {
        let sent = try json(row(bars: nil))
        #expect(!sent.keys.contains("video_path"))
        #expect(!sent.keys.contains("coach_notes"))
    }

    @Test func rowsWithoutBarsStillDecode() throws {
        let old = """
        {"id":"\(UUID().uuidString)","routine_id":"\(UUID().uuidString)","x":1,"y":2,"figure_name":"Whisk",
         "rhythm":"","notes":"","video_path":null,"order_index":0,"transition_notes":""}
        """
        let decoded = try JSONDecoder().decode(DBCanvasNodeRow.self, from: Data(old.utf8))
        #expect(decoded.bars == nil)
    }
}
