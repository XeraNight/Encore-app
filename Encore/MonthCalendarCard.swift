import SwiftUI

// MARK: - Month calendar (shared by Súťaže → Výsledky and Plán → Kalendár)
/// How one day looks in the grid.
struct CalendarDayMark: Equatable {
    enum Ring: Equatable {
        /// Gold outline: something that happened (a saved result).
        case solid
        /// Dashed gold outline: something planned (a competition ahead).
        case dashed
        /// Filled gold: a podium (1.–3. place).
        case filled
    }

    var ring: Ring? = nil
    /// Up to three dots under the number (discipline or kind of training).
    var dots: [Color] = []

    var isEmpty: Bool { ring == nil && dots.isEmpty }
}

/// Month grid on a glass card (BRAND_GUIDELINES §1A): arrows or a horizontal swipe change the month (the new
/// month slides in from the right side), "Dnes" jumps back, the gold selection slides between days.
struct MonthCalendarCard: View {
    @Binding var month: Date
    @Binding var selectedDay: Date?
    let mark: (Date) -> CalendarDayMark
    var legend: [(mark: CalendarDayMark, title: String)] = []
    /// Plán lets every day be picked (to add something); Výsledky only days with a mark.
    var selectsEmptyDays = false
    /// Tapping the selected day again clears the selection (Výsledky shows the whole month then).
    var deselectsOnSecondTap = true
    var accessibilityLabel: (Date) -> String = { $0.formatted(.dateTime.day().month(.wide)) }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace
    /// +1 when the next month comes in from the right, -1 from the left.
    @State private var direction = 1

    static let calendar = PlannerCalendar.calendar

    var body: some View {
        VStack(spacing: 10) {
            header
            weekdayRow
            ZStack {
                monthGrid
                    .id(month)
                    .transition(monthTransition)
            }
            .clipped()
            if !legend.isEmpty { legendRow }
        }
        .padding(14)
        .homeCard(cornerRadius: 20)
        .simultaneousGesture(swipe)
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
                Button("Dnes") {
                    show(Self.startOfMonth(Date()), selecting: selectsEmptyDays ? Self.calendar.startOfDay(for: Date()) : nil)
                }
                .font(.caption.weight(.bold))
                .foregroundColor(Color.obsidian900)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gold400, in: Capsule())
                .frame(minHeight: 44)
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
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
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
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let dayMark = mark(day)
        let isSelected = selectedDay == day
        let isToday = Self.calendar.isDateInToday(day)
        let content = ZStack {
            if isSelected {
                Circle()
                    .fill(Color.gold400.opacity(0.18))
                    .overlay(Circle().stroke(Color.gold400, lineWidth: 1.5))
                    .frame(width: 40, height: 40)
                    .matchedGeometryEffect(id: "selectedDay", in: selectionNamespace)
            }
            ring(dayMark.ring, isToday: isToday)
            Text("\(Self.calendar.component(.day, from: day))")
                .font(.system(.subheadline, design: .rounded).weight(dayMark.isEmpty ? .medium : .heavy))
                .foregroundColor(numberColor(dayMark, isToday: isToday))
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .overlay(alignment: .bottom) {
            HStack(spacing: 3) {
                ForEach(Array(dayMark.dots.prefix(3).enumerated()), id: \.offset) { _, color in
                    Circle().fill(color).frame(width: 5, height: 5)
                }
            }
            .offset(y: 1)
        }
        .scaleEffect(isSelected ? 1.08 : 1)
        .contentShape(Rectangle())

        if dayMark.isEmpty && !selectsEmptyDays {
            content.accessibilityHidden(true)
        } else {
            Button {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.75)) {
                    selectedDay = isSelected && deselectsOnSecondTap ? nil : day
                }
            } label: {
                content
            }
            .buttonStyle(.pressable(scale: 0.88))
            .accessibilityLabel(accessibilityLabel(day))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    @ViewBuilder
    private func ring(_ ring: CalendarDayMark.Ring?, isToday: Bool) -> some View {
        switch ring {
        case .filled:
            Circle().fill(Color.goldLinearGradient).frame(width: 32, height: 32)
        case .solid:
            Circle().stroke(Color.gold500.opacity(0.85), lineWidth: 1.2).frame(width: 32, height: 32)
        case .dashed:
            Circle()
                .stroke(Color.gold400.opacity(0.9), style: StrokeStyle(lineWidth: 1.2, dash: [3, 2.5]))
                .frame(width: 32, height: 32)
        case nil:
            if isToday {
                Circle().fill(Color.white.opacity(0.12)).frame(width: 32, height: 32)
            }
        }
    }

    private func numberColor(_ dayMark: CalendarDayMark, isToday: Bool) -> Color {
        if dayMark.ring == .filled { return Color.obsidian900 }
        if dayMark.ring != nil { return Color.gold300 }
        return .white.opacity(isToday || !dayMark.dots.isEmpty ? 1 : 0.55)
    }

    private var legendRow: some View {
        HStack(spacing: 12) {
            ForEach(Array(legend.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 5) {
                    legendSymbol(item.mark)
                    Text(item.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func legendSymbol(_ item: CalendarDayMark) -> some View {
        switch item.ring {
        case .filled: Circle().fill(Color.goldLinearGradient).frame(width: 9, height: 9)
        case .solid: Circle().stroke(Color.gold500, lineWidth: 1.2).frame(width: 9, height: 9)
        case .dashed: Circle().stroke(Color.gold400, style: StrokeStyle(lineWidth: 1.2, dash: [2, 1.5])).frame(width: 9, height: 9)
        case nil: Circle().fill(item.dots.first ?? .white).frame(width: 6, height: 6)
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

    private func show(_ newMonth: Date, selecting day: Date? = nil) {
        guard newMonth != month else {
            if let day { selectedDay = day }
            return
        }
        // The outgoing grid must render with the new direction before it is removed, so set it first.
        direction = newMonth > month ? 1 : -1
        Task { @MainActor in
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.42, dampingFraction: 0.86)) {
                month = newMonth
                selectedDay = day
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

    // MARK: Dates

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

    static func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
    }
}

// MARK: - Results on the calendar
extension CompetitionResult {
    /// Gold ring (filled for 1.–3. place) and a dot in the discipline colour.
    static func calendarMark(for results: [CompetitionResult]) -> CalendarDayMark {
        guard !results.isEmpty else { return CalendarDayMark() }
        let isPodium = results.contains { ($0.placement ?? Int.max) <= 3 }
        return CalendarDayMark(
            ring: isPodium ? .filled : .solid,
            dots: results.map { $0.discipline == "LAT" ? Color.latinPink : Color.standardBlue }
        )
    }
}
