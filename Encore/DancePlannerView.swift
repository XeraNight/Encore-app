import Combine
import SwiftUI
import SwiftData

// MARK: - Shared card look for the planner
extension View {
    func plannerCard(cornerRadius: CGFloat = 18) -> some View {
        self
            .padding(14)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

func plannerSectionTitle(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 11, weight: .black, design: .rounded))
        .foregroundColor(Color.gold400)
        .tracking(1.4)
}

// MARK: - Planner tab ("Plán")
/// Third dock tab: today's training, the permanent weekly rhythm and tracked competitions.
struct DancePlannerView: View {
    enum Section: String, CaseIterable, Identifiable {
        case today = "Dnes", calendar = "Kalendár", routine = "Režim"
        var id: String { rawValue }
    }

    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \TrainingCadence.startMinutes) private var cadences: [TrainingCadence]
    @Query(sort: \TrainingLogEntry.day, order: .reverse) private var logs: [TrainingLogEntry]
    @Query(sort: \PlannedCompetition.date) private var competitions: [PlannedCompetition]
    @Query(sort: \PlannedSession.start) private var sessions: [PlannedSession]

    @State private var section: Section = .today
    @Namespace private var sectionNamespace
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var router = PlannerRouter.shared
    @State private var debriefEntry: TrainingLogEntry?
    /// Rebuilds the sections when the day changes while the app is open (midnight) or comes back the next day.
    @State private var today = PlannerCalendar.startOfDay(Date())

    /// Changes whenever something that affects notifications changes.
    private var planSignature: String {
        let c = cadences.map { "\($0.id)\($0.weekday)\($0.startMinutes)\($0.durationMinutes)\($0.isEnabled)" }
        let l = logs.filter { $0.status == .skipped }.map { "\($0.id)" }
        let k = competitions.map { "\($0.id)\($0.date.timeIntervalSince1970)\($0.entryDeadline?.timeIntervalSince1970 ?? 0)\($0.intentRaw)" }
        let s = sessions.map { "\($0.id)\($0.start.timeIntervalSince1970)\($0.durationMinutes)\($0.goal)" }
        return (c + l + k + s).joined(separator: "|")
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
        .task(id: planSignature) {
            await PlannerNotifications.reschedule(cadences: cadences, logs: logs, competitions: competitions, sessions: sessions)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshDay()
            Task {
                await NotificationManager.shared.checkAuthorizationStatus()
                await PlannerNotifications.reschedule(cadences: cadences, logs: logs, competitions: competitions, sessions: sessions)
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
            Text("PLÁN")
                .font(.system(size: 13, weight: .black, design: .rounded))
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
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
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
