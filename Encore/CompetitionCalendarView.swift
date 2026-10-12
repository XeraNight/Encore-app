import SwiftUI

// MARK: - Kalendár výsledkov
/// Saved KSIS results on a month grid (BRAND_GUIDELINES §1A). Arrows or a horizontal swipe change the month;
/// a day with a competition is gold (filled for 1.–3. place) with a dot per discipline. Below the grid are the
/// results of the tapped day, or of the whole month when no day is selected.
struct CompetitionCalendarView: View {
    let results: [CompetitionResult]
    let onSelect: (CompetitionResult) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace
    @State private var month: Date
    @State private var selectedDay: Date?
    /// +1 when the next month comes in from the right, -1 from the left.
    @State private var direction = 1

    private static let calendar = PlannerCalendar.calendar
    private static let slovak = Locale(identifier: "sk")

    init(results: [CompetitionResult], onSelect: @escaping (CompetitionResult) -> Void) {
        self.results = results
        self.onSelect = onSelect
        // Open on the month of the latest competition already danced, so the past is one swipe away.
        let latest = results.compactMap(\.dateValue).filter { $0 <= Date() }.max() ?? Date()
        _month = State(initialValue: Self.startOfMonth(latest))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 10) {
                header
                weekdayRow
                ZStack {
                    monthGrid
                        .id(month)
                        .transition(monthTransition)
                }
                .clipped()
                legend
            }
            .padding(14)
            .homeCard(cornerRadius: 20)
            .simultaneousGesture(swipe)

            listCaption
            resultList
        }
        .sensoryFeedback(.selection, trigger: selectedDay)
        .sensoryFeedback(.impact(weight: .light), trigger: month)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Text(monthTitle)
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundColor(.white)
                .contentTransition(.numericText(countsDown: direction < 0))
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 4)

            if !isCurrentMonth {
                Button("Dnes") { show(Self.startOfMonth(Date())) }
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color.obsidian900)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gold400, in: Capsule())
                    .buttonStyle(.pressable(scale: 0.92))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }

            arrowButton("chevron.left", label: "Predchádzajúci mesiac", offset: -1)
            arrowButton("chevron.right", label: "Ďalší mesiac", offset: 1)
        }
    }

    private func arrowButton(_ systemImage: String, label: String, offset: Int) -> some View {
        Button {
            if let next = Self.calendar.date(byAdding: .month, value: offset, to: month) { show(next) }
        } label: {
            Image(systemName: systemImage)
                .font(.footnote.weight(.bold))
                .foregroundColor(Color.gold400)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.07), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.pressable(scale: 0.88))
        .accessibilityLabel(label)
    }

    private var weekdayRow: some View {
        let symbols = Self.calendar.shortStandaloneWeekdaySymbols
        // Calendar symbols start on Sunday; the grid starts on Monday.
        let mondayFirst = Array(symbols[1...]) + [symbols[0]]
        return HStack(spacing: 0) {
            ForEach(Array(mondayFirst.enumerated()), id: \.offset) { _, symbol in
                Text(symbol.uppercased())
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Grid

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
            ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 42)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let dayResults = resultsByDay[day] ?? []
        let number = Text("\(Self.calendar.component(.day, from: day))")
        if dayResults.isEmpty {
            number
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .foregroundColor(.white.opacity(Self.calendar.isDateInToday(day) ? 1 : 0.55))
                .frame(maxWidth: .infinity, minHeight: 42)
                .overlay {
                    if Self.calendar.isDateInToday(day) {
                        Circle()
                            .stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: 34, height: 34)
                    }
                }
                .accessibilityHidden(true)
        } else {
            let isSelected = selectedDay == day
            let isPodium = dayResults.contains { ($0.placement ?? Int.max) <= 3 }
            Button {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.75)) {
                    selectedDay = isSelected ? nil : day
                }
            } label: {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(Color.gold400.opacity(0.18))
                            .overlay(Circle().stroke(Color.gold400, lineWidth: 1.5))
                            .frame(width: 40, height: 40)
                            .matchedGeometryEffect(id: "selectedDay", in: selectionNamespace)
                    }
                    if isPodium {
                        Circle().fill(Color.goldLinearGradient).frame(width: 32, height: 32)
                    } else {
                        Circle().stroke(Color.gold500.opacity(0.8), lineWidth: 1.2).frame(width: 32, height: 32)
                    }
                    number
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .foregroundColor(isPodium ? Color.obsidian900 : Color.gold300)
                }
                .frame(maxWidth: .infinity, minHeight: 42)
                .overlay(alignment: .bottom) {
                    HStack(spacing: 3) {
                        ForEach(dayResults.prefix(3)) { result in
                            Circle()
                                .fill(result.discipline == "LAT" ? Color.latinPink : Color.standardBlue)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .offset(y: 3)
                }
                .scaleEffect(isSelected ? 1.08 : 1)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(scale: 0.88))
            .accessibilityLabel(dayAccessibilityLabel(day, dayResults))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(Circle().fill(Color.goldLinearGradient), "Pódium")
            legendItem(Circle().fill(Color.standardBlue), "Štandard")
            legendItem(Circle().fill(Color.latinPink), "Latina")
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private func legendItem(_ dot: some View, _ title: String) -> some View {
        HStack(spacing: 5) {
            dot.frame(width: 7, height: 7)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: Results below the grid

    private var shownResults: [CompetitionResult] {
        guard let selectedDay else { return monthResults }
        return resultsByDay[selectedDay] ?? []
    }

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
    private var resultList: some View {
        let shown = shownResults
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

    // MARK: Month change

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > 50, abs(dx) > abs(value.translation.height) * 1.5,
                      let next = Self.calendar.date(byAdding: .month, value: dx < 0 ? 1 : -1, to: month) else { return }
                show(next)
            }
    }

    private func show(_ newMonth: Date) {
        guard newMonth != month else { return }
        // The outgoing grid must render with the new direction before it is removed, so set it first.
        direction = newMonth > month ? 1 : -1
        Task { @MainActor in
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.86)) {
                month = newMonth
                selectedDay = nil
            }
        }
    }

    private var monthTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: direction > 0 ? .leading : .trailing).combined(with: .opacity)
        )
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

    /// The month's days with leading and trailing blanks so the grid starts on Monday and ends on Sunday.
    private var gridDays: [Date?] {
        let count = Self.calendar.range(of: .day, in: .month, for: month)?.count ?? 0
        let leading = PlannerCalendar.isoWeekday(of: month) - 1
        var days: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<count {
            days.append(Self.calendar.date(byAdding: .day, value: offset, to: month))
        }
        days.append(contentsOf: Array(repeating: nil, count: (7 - days.count % 7) % 7))
        return days
    }

    private var monthTitle: String {
        let index = Self.calendar.component(.month, from: month) - 1
        let name = Self.calendar.standaloneMonthSymbols[index]
        return "\(name.prefix(1).uppercased())\(name.dropFirst()) \(Self.calendar.component(.year, from: month))"
    }

    private var isCurrentMonth: Bool {
        Self.calendar.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private func dayAccessibilityLabel(_ day: Date, _ dayResults: [CompetitionResult]) -> String {
        let date = day.formatted(.dateTime.day().month(.wide).locale(Self.slovak))
        let places = dayResults.map { "\($0.categoryName), \($0.placeLine)" }.joined(separator: "; ")
        return "\(date): \(places)"
    }

    private static func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
    }

}
