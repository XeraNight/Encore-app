import SwiftUI

// MARK: - Kalendár výsledkov
/// Saved KSIS results on the shared month calendar. Below the grid are the results of the tapped day, or of
/// the whole month when no day is selected.
struct CompetitionCalendarView: View {
    let results: [CompetitionResult]
    let onSelect: (CompetitionResult) -> Void

    @State private var month: Date
    @State private var selectedDay: Date?

    private static let calendar = PlannerCalendar.calendar
    private static let slovak = Locale(identifier: "sk")

    init(results: [CompetitionResult], onSelect: @escaping (CompetitionResult) -> Void) {
        self.results = results
        self.onSelect = onSelect
        // Open on the month of the latest competition already danced, so the past is one swipe away.
        let latest = results.compactMap(\.dateValue).filter { $0 <= Date() }.max() ?? Date()
        _month = State(initialValue: MonthCalendarCard.startOfMonth(latest))
    }

    var body: some View {
        let byDay = resultsByDay
        VStack(alignment: .leading, spacing: 12) {
            MonthCalendarCard(
                month: $month,
                selectedDay: $selectedDay,
                mark: { CompetitionResult.calendarMark(for: byDay[$0] ?? []) },
                legend: [
                    (CalendarDayMark(ring: .filled), "Pódium"),
                    (CalendarDayMark(dots: [.standardBlue]), "Štandard"),
                    (CalendarDayMark(dots: [.latinPink]), "Latina"),
                ],
                accessibilityLabel: { day in
                    let date = day.formatted(.dateTime.day().month(.wide).locale(Self.slovak))
                    let places = (byDay[day] ?? []).map { "\($0.categoryName), \($0.placeLine)" }.joined(separator: "; ")
                    return "\(date): \(places)"
                }
            )

            listCaption
            resultList(byDay)
        }
        .onChange(of: month) { _, _ in selectedDay = nil }
    }

    // MARK: Results below the grid

    private var listCaption: some View {
        HStack(spacing: 6) {
            Text(captionText)
                .font(.system(.footnote, design: .rounded).weight(.heavy))
                .foregroundColor(.white.opacity(0.5))
                .contentTransition(.numericText())
            Spacer(minLength: 8)
            if selectedDay != nil {
                Button("Celý mesiac") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedDay = nil }
                }
                .font(.caption.weight(.bold))
                .foregroundColor(Color.gold400)
                .frame(minHeight: 44)
                .buttonStyle(.pressable(scale: 0.94))
                .transition(.opacity)
            }
        }
        .padding(.top, 4)
    }

    private var captionText: String {
        if let selectedDay {
            return selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Self.slovak))
        }
        let count = monthResults.count
        guard count > 0 else { return "V tomto mesiaci žiadna súťaž" }
        let points = monthResults.reduce(0) { $0 + $1.pointsEarned }
        return "\(slovakCount(count, one: "súťaž", few: "súťaže", many: "súťaží")) · +\(points) b"
    }

    @ViewBuilder
    private func resultList(_ byDay: [Date: [CompetitionResult]]) -> some View {
        let shown = selectedDay.map { byDay[$0] ?? [] } ?? monthResults
        if !shown.isEmpty {
            VStack(spacing: 0) {
                ForEach(shown) { result in
                    Button { onSelect(result) } label: {
                        CompetitionResultRow(result: result)
                    }
                    .buttonStyle(.pressable(scale: 0.98))
                    if result.id != shown.last?.id {
                        HomeRowDivider()
                    }
                }
            }
            .homeCard(cornerRadius: 20)
            .id(selectedDay ?? month)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }

    // MARK: Data

    private var resultsByDay: [Date: [CompetitionResult]] {
        var byDay: [Date: [CompetitionResult]] = [:]
        for result in results {
            guard let date = result.dateValue else { continue }
            byDay[Self.calendar.startOfDay(for: date), default: []].append(result)
        }
        return byDay
    }

    private var monthResults: [CompetitionResult] {
        results
            .filter { result in
                guard let date = result.dateValue else { return false }
                return Self.calendar.isDate(date, equalTo: month, toGranularity: .month)
            }
            .sorted { $0.date > $1.date }
    }
}
