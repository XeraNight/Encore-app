import SwiftUI
import SwiftData

/// "Dnes" part of the planner: today's sessions with one-tap check-in, next competition, recent reflections.
struct PlannerTodayView: View {
    let cadences: [TrainingCadence]
    let logs: [TrainingLogEntry]
    let competitions: [PlannedCompetition]
    let sessions: [PlannedSession]
    let onOpenRoutine: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var debriefEntry: TrainingLogEntry?
    @State private var editingCadence: TrainingCadence?
    @State private var editingSession: PlannedSession?
    @State private var changeTick = 0

    private var today: Date { PlannerCalendar.startOfDay(Date()) }

    private var todaysTrainings: [TrainingOccurrence] {
        TrainingOccurrence.on(today, cadences: cadences, sessions: sessions, logs: logs)
    }

    private var nextSession: (cadence: TrainingCadence, day: Date)? {
        let cal = PlannerCalendar.calendar
        for offset in 1...7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let weekday = PlannerCalendar.isoWeekday(of: day)
            if let cadence = cadences
                .filter({ $0.isEnabled && $0.weekday == weekday })
                .min(by: { $0.startMinutes < $1.startMinutes }) {
                return (cadence, day)
            }
        }
        return nil
    }

    private var nextCompetition: PlannedCompetition? {
        competitions.first { $0.intent != .declined && PlannerCalendar.startOfDay($0.date) >= today }
    }

    private var recentReflections: [TrainingLogEntry] {
        Array(logs.filter { !$0.reflectionNote.isEmpty }.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .textCase(.uppercase)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            trainingsSection

            LessonPrioritiesSection()

            if let comp = nextCompetition {
                competitionCard(comp)
            }

            if !recentReflections.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    plannerSectionTitle("POSLEDNÉ REFLEXIE")
                    ForEach(recentReflections) { entry in
                        reflectionRow(entry)
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: changeTick)
        .sheet(item: $debriefEntry) { entry in
            DebriefSheet(entry: entry)
                .presentationDetents([.large])
        }
        .sheet(item: $editingCadence) { CadenceEditorSheet(cadence: $0) }
        .sheet(item: $editingSession) { SessionEditorSheet(session: $0) }
    }

    // MARK: Trainings
    @ViewBuilder
    private var trainingsSection: some View {
        if cadences.isEmpty && todaysTrainings.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Nastav si týždenný režim")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("Raz zadáš, kedy trénuješ. Potom ti stačí v daný deň ťuknúť Idem alebo Vynechávam a po tréningu zapísať, čo si sa naučil.")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.6))
                Button(action: onOpenRoutine) {
                    Text("Nastaviť režim")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color.obsidian900)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.gold400, in: Capsule())
                }
                .buttonStyle(.pressable)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .plannerCard()
        } else if todaysTrainings.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Dnes máš voľno")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                if let next = nextSession {
                    Text("Najbližší tréning: \(PlannerCalendar.weekdayName(iso: next.cadence.weekday)) \(PlannerCalendar.timeString(minutes: next.cadence.startMinutes)), \(next.cadence.title)")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .plannerCard()
        } else {
            ForEach(todaysTrainings) { occurrence in
                TrainingOccurrenceCard(
                    occurrence: occurrence,
                    entry: occurrence.entry(in: logs),
                    onSetStatus: { setStatus($0, for: occurrence) },
                    onDebrief: { debriefEntry = entryCreatingIfNeeded(for: occurrence) },
                    onEdit: {
                        switch occurrence.source {
                        case .weekly(let cadence): editingCadence = cadence
                        case .session(let session): editingSession = session
                        }
                    }
                )
            }
        }
    }

    private func entryCreatingIfNeeded(for occurrence: TrainingOccurrence) -> TrainingLogEntry {
        switch occurrence.source {
        case .weekly(let cadence):
            return PlannerAttendance.entryCreatingIfNeeded(cadence: cadence, on: today, in: logs, context: modelContext)
        case .session(let session):
            return PlannerAttendance.entryCreatingIfNeeded(session: session, in: logs, context: modelContext)
        }
    }

    private func setStatus(_ status: TrainingStatus, for occurrence: TrainingOccurrence) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            switch occurrence.source {
            case .weekly(let cadence):
                PlannerAttendance.setStatus(status, cadence: cadence, on: today, logs: logs, context: modelContext)
            case .session(let session):
                PlannerAttendance.setStatus(status, session: session, logs: logs, context: modelContext)
            }
        }
        changeTick += 1
    }

    // MARK: Competition
    private func competitionCard(_ comp: PlannedCompetition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            plannerSectionTitle("NAJBLIŽŠIA SÚŤAŽ")
            HStack(alignment: .firstTextBaseline) {
                Text("\(PlannerCalendar.daysText(until: comp.date)) — \(comp.name)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer(minLength: 8)
                Text(comp.intent.title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(comp.intent == .going ? Color.obsidian900 : Color.gold300)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(comp.intent == .going ? Color.gold400 : Color.gold500.opacity(0.14), in: Capsule())
            }
            if !comp.city.isEmpty {
                Text(comp.city)
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            if let deadline = comp.entryDeadline,
               PlannerCalendar.startOfDay(deadline) >= today,
               (PlannerCalendar.calendar.dateComponents([.day], from: today, to: PlannerCalendar.startOfDay(deadline)).day ?? 99) <= 7 {
                Label("Uzávierka prihlášok: \(deadline.formatted(.dateTime.weekday(.wide).day().month()))",
                      systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.latinCrimson)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plannerCard()
    }

    private func reflectionRow(_ entry: TrainingLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.feeling?.emoji ?? "📝")
                Text(entry.title.isEmpty ? "Tréning" : entry.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(entry.day, format: .dateTime.day().month(.abbreviated))
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            Text(entry.reflectionNote)
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.75))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plannerCard(cornerRadius: 14)
    }
}
