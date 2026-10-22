import Charts
import SwiftData
import SwiftUI

// MARK: - Vývoj tréningov (Kalendár, Plus)
/// The weeks and months behind "Tento týždeň": hours trained in the last 12 weeks (samotréning apart),
/// each month of the season with trainings done and cancelled, the dances worked on most, how trainings
/// felt and how many Top 3 items were ticked off. A training counts once it ended and was not cancelled,
/// like in "Tento týždeň"; a weekly training counts from the day it was added.
struct TrainingTrends: Equatable {
    struct Week: Identifiable, Equatable {
        let start: Date
        let soloMinutes: Int
        let otherMinutes: Int
        var id: Date { start }
        var totalMinutes: Int { soloMinutes + otherMinutes }
    }

    struct Month: Identifiable, Equatable {
        let start: Date
        let done: Int
        let cancelled: Int
        let reflections: Int
        var id: Date { start }
        var attendance: Double? { done + cancelled > 0 ? Double(done) / Double(done + cancelled) : nil }
    }

    struct DanceCount: Identifiable, Equatable {
        let dance: String
        let count: Int
        var id: String { dance }
    }

    static let weekCount = 12

    let weeks: [Week]
    let months: [Month]
    let dances: [DanceCount]
    let feelings: [TrainingFeeling: Int]
    let prioritiesDone: Int
    let seasonStart: Date

    var isEmpty: Bool { weeks.allSatisfy { $0.totalMinutes == 0 } && months.allSatisfy { $0.done + $0.cancelled == 0 } }

    init(cadences: [TrainingCadence], sessions: [PlannedSession], logs: [TrainingLogEntry],
         priorities: [LessonPriority], now: Date = Date()) {
        let cal = PlannerCalendar.calendar
        let today = cal.startOfDay(for: now)
        let thisMonday = cal.date(byAdding: .day, value: 1 - PlannerCalendar.isoWeekday(of: today), to: today) ?? today
        let firstMonday = cal.date(byAdding: .weekOfYear, value: -(Self.weekCount - 1), to: thisMonday) ?? thisMonday
        let seasonStart = PlannerCalendar.seasonStart(of: now)
        self.seasonStart = seasonStart
        let from = min(firstMonday, seasonStart)

        var weekSolo: [Date: Int] = [:], weekOther: [Date: Int] = [:]
        var monthDone: [Date: Int] = [:], monthCancelled: [Date: Int] = [:]
        var day = from
        while day <= today {
            let monday = cal.date(byAdding: .day, value: 1 - PlannerCalendar.isoWeekday(of: day), to: day) ?? day
            let month = cal.date(from: cal.dateComponents([.year, .month], from: day)) ?? day
            for occurrence in TrainingOccurrence.on(day, cadences: cadences, sessions: sessions, logs: logs, wholePast: true)
            where occurrence.hasTime && occurrence.end <= now {
                if occurrence.entry(in: logs)?.status == .skipped {
                    if day >= seasonStart { monthCancelled[month, default: 0] += 1 }
                    continue
                }
                let minutes = Int(occurrence.end.timeIntervalSince(occurrence.start) / 60)
                if occurrence.isSolo { weekSolo[monday, default: 0] += minutes } else { weekOther[monday, default: 0] += minutes }
                if day >= seasonStart { monthDone[month, default: 0] += 1 }
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        weeks = (0..<Self.weekCount).compactMap { offset in
            guard let start = cal.date(byAdding: .weekOfYear, value: offset, to: firstMonday) else { return nil }
            return Week(start: start, soloMinutes: weekSolo[start] ?? 0, otherMinutes: weekOther[start] ?? 0)
        }

        let seasonLogs = logs.filter { $0.day >= seasonStart && $0.day <= now }
        var monthReflections: [Date: Int] = [:]
        for entry in seasonLogs where !entry.reflectionNote.isEmpty {
            let month = cal.date(from: cal.dateComponents([.year, .month], from: entry.day)) ?? entry.day
            monthReflections[month, default: 0] += 1
        }
        var monthStarts: [Date] = []
        var month = seasonStart
        while month <= today {
            monthStarts.append(month)
            guard let next = cal.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        months = monthStarts.map {
            Month(start: $0, done: monthDone[$0] ?? 0, cancelled: monthCancelled[$0] ?? 0, reflections: monthReflections[$0] ?? 0)
        }

        dances = Dictionary(grouping: seasonLogs.compactMap(\.danceName), by: { $0 })
            .map { DanceCount(dance: $0.key, count: $0.value.count) }
            .sorted { ($0.count, -DanceNames.rank($0.dance)) > ($1.count, -DanceNames.rank($1.dance)) }
        feelings = Dictionary(grouping: seasonLogs.compactMap(\.feeling), by: { $0 }).mapValues(\.count)
        prioritiesDone = priorities.filter { ($0.doneAt ?? .distantPast) >= seasonStart }.count
    }
}

// MARK: - Screen
struct TrainingTrendsView: View {
    let cadences: [TrainingCadence]
    let sessions: [PlannedSession]
    let logs: [TrainingLogEntry]

    @Environment(\.dismiss) private var dismiss
    @Query private var priorities: [LessonPriority]
    @State private var trends: TrainingTrends?

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    if let trends {
                        TrainingTrendsContent(trends: trends)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 40)
                            .transition(.opacity)
                    } else {
                        ProgressView().tint(Color.gold400).padding(.top, 80)
                    }
                }
            }
            .navigationTitle("Vývoj")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zavrieť") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "sk"))
        .task {
            // A season of days is counted once when the screen opens, not on every redraw.
            let counted = TrainingTrends(cadences: cadences, sessions: sessions, logs: logs, priorities: priorities)
            withAnimation(.easeOut(duration: 0.25)) { trends = counted }
        }
    }
}

struct TrainingTrendsContent: View {
    let trends: TrainingTrends

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if trends.isEmpty {
                Text("Keď budeš mať za sebou pár tréningov, uvidíš tu hodiny po týždňoch, mesiace sezóny a tance, ktoré riešiš najviac.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .homeCard(cornerRadius: 20)
            } else {
                weeksSection
                monthsSection
                if !trends.dances.isEmpty || !trends.feelings.isEmpty || trends.prioritiesDone > 0 {
                    seasonSection
                }
            }
            Text("Tréning sa ráta, keď skončil a nezrušil si ho. Týždenný tréning od dňa, keď si ho pridal.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Weeks
    private var weeksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "HODINY ZA \(TrainingTrends.weekCount) TÝŽDŇOV", systemImage: "chart.bar.fill")
            VStack(alignment: .leading, spacing: 10) {
                Chart {
                    ForEach(trends.weeks) { week in
                        BarMark(x: .value("Týždeň", week.start, unit: .weekOfYear),
                                y: .value("Hodiny", Double(week.otherMinutes) / 60))
                            .foregroundStyle(by: .value("Druh", "Tréningy"))
                        BarMark(x: .value("Týždeň", week.start, unit: .weekOfYear),
                                y: .value("Hodiny", Double(week.soloMinutes) / 60))
                            .foregroundStyle(by: .value("Druh", "Samotréning"))
                    }
                }
                .chartForegroundStyleScale(["Tréningy": Color.white.opacity(0.75), "Samotréning": Color.gold400])
                .chartLegend(position: .bottom, alignment: .leading)
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel { Text("\(value.as(Double.self).map { Int($0) } ?? 0) h").foregroundStyle(Color.textSecondary) }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(Locale(identifier: "sk")))
                            .foregroundStyle(Color.textSecondary)
                    }
                }
                .frame(height: 190)
            }
            .padding(14)
            .homeCard(cornerRadius: 20)
        }
    }

    // MARK: Months
    private var monthsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "MESIACE SEZÓNY", systemImage: "calendar")
            VStack(spacing: 0) {
                ForEach(trends.months.reversed()) { month in
                    HStack(spacing: 12) {
                        Text(month.start.formatted(.dateTime.month(.wide).locale(Locale(identifier: "sk"))).capitalized)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(width: 90, alignment: .leading)
                        VStack(alignment: .leading, spacing: 4) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.08))
                                    Capsule()
                                        .fill(LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: geo.size.width * (month.attendance ?? 0))
                                }
                            }
                            .frame(height: 6)
                            Text(monthDetail(month))
                                .font(.caption2)
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .combine)
                    if month.id != trends.months.first?.id { HomeRowDivider() }
                }
            }
            .homeCard(cornerRadius: 20)
        }
    }

    private func monthDetail(_ month: TrainingTrends.Month) -> String {
        var parts = [slovakCount(month.done, one: "tréning", few: "tréningy", many: "tréningov")]
        if month.cancelled > 0 { parts.append("\(month.cancelled) zrušené") }
        if month.reflections > 0 {
            parts.append(slovakCount(month.reflections, one: "reflexia", few: "reflexie", many: "reflexií"))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Season
    private var seasonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "TÁTO SEZÓNA", systemImage: "sparkles")
            VStack(alignment: .leading, spacing: 14) {
                if trends.prioritiesDone > 0 {
                    Label("Zvládnuté priority z Top 3: \(trends.prioritiesDone)", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color.syncEmerald)
                }
                if !trends.dances.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Najviac riešené tance")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Color.textSecondary)
                        ForEach(trends.dances.prefix(5)) { dance in
                            HStack {
                                Text(DanceNames.display(dance.dance))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(dance.count)×")
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .monospacedDigit()
                                    .foregroundColor(Color.gold300)
                            }
                        }
                    }
                }
                if !trends.feelings.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(TrainingFeeling.allCases) { feeling in
                            VStack(spacing: 2) {
                                Image(systemName: feeling.symbol).font(.title2).foregroundStyle(Color.gold400)
                                Text("\(trends.feelings[feeling] ?? 0)")
                                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                                    .foregroundColor(.white)
                                Text(feeling.title)
                                    .font(.caption2)
                                    .foregroundColor(Color.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCard(cornerRadius: 20)
        }
    }
}
