import Foundation

/// Where an update from KSIS is: which of its steps, and how far through the one it is on.
struct KSISReadingProgress: Equatable {
    enum Stage: Int, CaseIterable {
        case couples, history, marks, cup, calendar

        var title: String {
            switch self {
            case .couples: return "Páry"
            case .history: return "História"
            case .marks: return "Krížiky"
            case .cup: return "Pohár"
            case .calendar: return "Kalendár"
            }
        }
    }

    var stage: Stage
    /// Pages of this step already read, out of `total`; nil while the number of pages is not known.
    var done: Int?
    var total: Int?
    var stageStartedAt: Date = Date()

    /// 0...1 inside the step; nil while it is not known.
    var fraction: Double? {
        guard let done, let total, total > 0 else { return nil }
        return min(1, max(0, Double(done) / Double(total)))
    }

    /// Seconds left for this step at the pace it has kept so far; nil until two pages have shown a pace.
    func secondsLeft(now: Date) -> TimeInterval? {
        guard let done, let total, done >= 2, total > done else { return nil }
        let perPage = now.timeIntervalSince(stageStartedAt) / Double(done)
        return perPage * Double(total - done)
    }

    /// "pár sekúnd", "asi 40 s", "asi 2 min": rounded, because an exact countdown would promise too much.
    static func waitText(_ seconds: TimeInterval) -> String {
        if seconds < 10 { return "pár sekúnd" }
        if seconds < 50 { return "asi \(Int((seconds / 5).rounded()) * 5) s" }
        return "asi \(max(1, Int((seconds / 60).rounded()))) min"
    }

    /// The steps an update of this kind goes through, in order.
    static func stages(for job: KSISUpdateJob) -> [Stage] {
        switch job {
        case .everything: return [.couples, .history, .marks, .cup, .calendar]
        case .calendar: return [.calendar]
        case .marks: return [.marks]
        }
    }
}
