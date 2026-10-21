import Foundation

/// How long a figure and a whole routine take: bars × 60 / the dance's tempo in bars per minute (MPM).
/// The tempo is the dancer's own one from the dance (seeded with the official range, editable), so
/// nothing here is guessed. A figure without bars simply does not count.
nonisolated enum RoutineTiming {
    static let barRange = 1...64

    /// The middle of the range in a tempo text like "28–30 MPM (84–90 BPM)" or "28–30 taktov za minútu".
    static func barsPerMinute(fromTempo tempo: String) -> Double? {
        // The beats per minute in brackets are not bars.
        let bars = tempo.components(separatedBy: "(").first ?? tempo
        let numbers = bars.split { !$0.isNumber }.compactMap { Double($0) }.prefix(2)
        guard !numbers.isEmpty, numbers.allSatisfy({ $0 > 0 }) else { return nil }
        return numbers.reduce(0, +) / Double(numbers.count)
    }

    static func seconds(bars: Int, barsPerMinute: Double) -> TimeInterval {
        Double(bars) * 60 / barsPerMinute
    }

    /// "4 s" under a minute, "1:35" from a minute up.
    static func text(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        guard total >= 60 else { return "\(total) s" }
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }

    /// "1 takt", "2 takty", "5 taktov".
    static func barsText(_ bars: Int) -> String {
        switch bars {
        case 1: return "1 takt"
        case 2...4: return "\(bars) takty"
        default: return "\(bars) taktov"
        }
    }
}

extension Routine {
    /// Bars of the figures that have them, and how many figures have none yet.
    var barsSummary: (bars: Int, missing: Int) {
        canvasNodes.reduce(into: (bars: 0, missing: 0)) { result, node in
            if let bars = node.bars { result.bars += bars } else { result.missing += 1 }
        }
    }
}

extension Array where Element == Dance {
    /// The tempo the dancer keeps for this dance, in bars per minute.
    func barsPerMinute(for danceName: String) -> Double? {
        first { $0.name == danceName }.flatMap { RoutineTiming.barsPerMinute(fromTempo: $0.tempo) }
    }
}
