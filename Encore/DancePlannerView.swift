import Combine
import SwiftUI
import SwiftData

// MARK: - Shared card look for the planner
/// The §1A glass card with the planner's inner padding.
extension View {
    func plannerCard(cornerRadius: CGFloat = 18) -> some View {
        padding(14).homeCard(cornerRadius: cornerRadius)
    }
}

func plannerSectionTitle(_ text: String) -> some View {
    Text(text)
        .font(.system(.caption, design: .rounded).weight(.black))
        .foregroundColor(Color.gold400)
        .tracking(1.4)
        .accessibilityAddTraits(.isHeader)
}

// MARK: - Kalendár tab
/// Third dock tab: today's training, the month with everything in it and the permanent weekly rhythm.
struct DancePlannerView: View {
    enum Section: String, CaseIterable, Identifiable {
        case today = "Dnes", calendar = "Mesiac", routine = "Režim"
        var id: String { rawValue }
    }

    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \TrainingCadence.startMinutes) private var cadences: [TrainingCadence]
    @Query(sort: \TrainingLogEntry.day, order: .reverse) private var logs: [TrainingLogEntry]
    @Query(sort: \PlannedCompetition.date) private var competitions: [PlannedCompetition]
    @Query(sort: \PlannedSession.start) private var sessions: [PlannedSession]
    @Query private var priorities: [LessonPriority]
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var section: Section = .today
    @Namespace private var sectionNamespace
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var router = PlannerRouter.shared
    @State private var debriefEntry: TrainingLogEntry?
    /// Rebuilds the sections when the day changes while the app is open (midnight) or comes back the next day.
    @State private var today = PlannerCalendar.startOfDay(Date())

    /// Changes whenever something that affects notifications changes.
    /// The reminder before a training with the open Top 3 is part of Plus.
    private var remindsFocus: Bool { subscriptionManager.currentTier >= .plus }

    private func reschedule() async {
        await PlannerNotifications.reschedule(cadences: cadences, logs: logs, competitions: competitions, sessions: sessions,
                                              priorities: priorities, remindsFocus: remindsFocus)
    }

    private var planSignature: String {
        let c = cadences.map { "\($0.id)\($0.weekday)\($0.startMinutes)\($0.durationMinutes)\($0.isEnabled)" }
        let l = logs.filter { $0.status == .skipped }.map { "\($0.id)" }
        let k = competitions.map { "\($0.id)\($0.date.timeIntervalSince1970)\($0.entryDeadline?.timeIntervalSince1970 ?? 0)\($0.intentRaw)" }
        let s = sessions.map { "\($0.id)\($0.start.timeIntervalSince1970)\($0.durationMinutes)\($0.goal)" }
        // Open Top 3 and Plus change what the reminder before a training says.
        let p = priorities.filter(\.isOpen).map { "\($0.id)\($0.text)" } + ["\(remindsFocus)"]
        return (c + l + k + s + p).joined(separator: "|")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                VStack(spacing: 14) {
                    header
                    sectionSwitcher

                    ScrollView(.vertical, showsIndicators: false) {
                        Group {
                            switch section {
                            case .today:
                                PlannerTodayView(
                                    cadences: cadences,
                                    logs: logs,
                                    competitions: competitions,
                                    sessions: sessions,
                                    onOpenRoutine: { section = .routine }
                                )
                            case .calendar:
                                VStack(alignment: .leading, spacing: 24) {
                                    PlannerCalendarView(
                                        cadences: cadences,
                                        logs: logs,
                                        competitions: competitions,
                                        sessions: sessions
                                    )
                                    PlannerCompetitionsView(competitions: competitions)
                                }
                            case .routine:
                                PlannerRoutineView(cadences: cadences)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120)
                        .transition(.opacity)
                        .id(today)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                .padding(.top, 8)
            }
            .toolbar(.hidden, for: .navigationBar)
            .environment(\.locale, Locale(identifier: "sk"))
        }
        .task(id: planSignature) { await reschedule() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshDay()
            Task {
                await NotificationManager.shared.checkAuthorizationStatus()
                await reschedule()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            refreshDay()
        }
        .sensoryFeedback(.selection, trigger: section)
        .onChange(of: router.pending, initial: true) { _, request in
            guard let request else { return }
            router.pending = nil
            open(request)
        }
        .sheet(item: $debriefEntry) { DebriefSheet(entry: $0).presentationDetents([.large]) }
    }

    private func refreshDay() {
        let now = PlannerCalendar.startOfDay(Date())
        if now != today { today = now }
    }

    /// Opens the reflection of the training a notification was about (if it still exists).
    private func open(_ request: PlannerOpenRequest) {
        switch request.target {
        case .weekly(let cadenceId, let day):
            guard let cadence = cadences.first(where: { $0.id == cadenceId }) else { return }
            debriefEntry = PlannerAttendance.entryCreatingIfNeeded(cadence: cadence, on: day, in: logs, context: modelContext)
        case .session(let id):
            guard let session = sessions.first(where: { $0.id == id }) else { return }
            debriefEntry = PlannerAttendance.entryCreatingIfNeeded(session: session, in: logs, context: modelContext)
        }
    }

    private var header: some View {
        HStack {
            Text("KALENDÁR")
                .font(.system(.footnote, design: .rounded).weight(.black))
                .foregroundColor(.white)
                .tracking(2.6)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
    }

    private var sectionSwitcher: some View {
        HStack(spacing: 8) {
            ForEach(Section.allCases) { item in
                let isSelected = section == item
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { section = item }
                } label: {
                    Text(item.rawValue)
                        .font(.footnote.weight(isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : Color.white.opacity(0.6))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background {
                            ZStack {
                                Capsule().fill(Color.white.opacity(0.04))
                                if isSelected {
                                    Capsule()
                                        .fill(Color.white.opacity(0.12))
                                        .matchedGeometryEffect(id: "plannerSection", in: sectionNamespace)
                                }
                            }
                        }
                        .overlay(
                            Capsule().stroke(
                                isSelected ? Color.gold400.opacity(0.4) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.horizontal, 20)
    }
}
