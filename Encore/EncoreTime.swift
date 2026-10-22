import Foundation

/// When something was saved (a note, a video) is one moment everywhere. Encore shows it in Slovak time, so a note
/// made at a competition in the USA reads the same back home, and while the iPhone is in another time zone the
/// time says so: "14:05 (čas SR)". Planned trainings stay in the time of the place, like in any calendar.
nonisolated enum EncoreTime {
    static let home = TimeZone(identifier: "Europe/Bratislava") ?? .current

    static func isAway(at date: Date = Date()) -> Bool {
        TimeZone.current.secondsFromGMT(for: date) != home.secondsFromGMT(for: date)
    }

    /// "14:05"
    static func clock(_ date: Date) -> String {
        format(date, .dateTime.hour().minute())
    }

    /// "22. okt 14:05"
    static func dayAndClock(_ date: Date) -> String {
        format(date, .dateTime.day().month(.abbreviated).hour().minute())
    }

    /// "streda 22. októbra 14:05"
    static func longDayAndClock(_ date: Date) -> String {
        format(date, .dateTime.weekday(.wide).day().month(.wide).hour().minute())
    }

    private static func format(_ date: Date, _ style: Date.FormatStyle) -> String {
        var style = style
        style.timeZone = home
        style.locale = Locale(identifier: "sk")
        let text = date.formatted(style)
        return isAway(at: date) ? text + " (čas SR)" : text
    }
}
