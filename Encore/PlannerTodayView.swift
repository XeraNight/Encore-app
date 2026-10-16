import SwiftUI
import SwiftData
import UserNotifications

/// "Dnes" part of the planner: today's sessions with one-tap check-in, next competition, recent reflections.
struct PlannerTodayView: View {
    let cadences: [TrainingCadence]
    let logs: [TrainingLogEntry]
    let competitions: [PlannedCompetition]
    let sessions: [PlannedSession]
    let onOpenRoutine: () -> Void

    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var notifications = NotificationManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var competitionDay: PlannedCompetition?
    @State private var showPaywall = false
    @State private var debriefEntry: TrainingLogEntry?
    @State private var editingCadence: TrainingCadence?
    @State private var editingSession: PlannedSession?
    @State private var changeTick = 0

    private var today: Date { PlannerCalendar.startOfDay(Date()) }

    private var todaysTrainings: [TrainingOccurrence] {
        TrainingOccurrence.on(today, cadences: cadences, sessions: sessions, logs: logs)
    }

    /// The next training after today that is not cancelled, weekly or one-off, within two weeks.
    private var nextTraining: TrainingOccurrence? {
        let cal = PlannerCalendar.calendar
        for offset in 1...14 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            if let next = TrainingOccurrence.on(day, cadences: cadences, sessions: sessions, logs: logs)
                .first(where: { $0.hasTime && $0.entry(in: logs)?.status != .skipped }) {
                return next
            }
        }
        return nil
    }

    private func nextTrainingText(_ next: TrainingOccurrence) -> String {
        let cal = PlannerCalendar.calendar
        let day = cal.isDateInTomorrow(next.day)
            ? "Zajtra"
            : PlannerCalendar.weekdayName(iso: PlannerCalendar.isoWeekday(of: next.day))
        return "Najbližší tréning: \(day) \(next.start.formatted(date: .omitted, time: .shortened)), \(next.title)"
    }

    /// Reminders need the system permission; a dancer who switched them off inside Encore is left alone.
    private var remindersBlocked: Bool {
        !notifications.isAuthorized && !(cadences.isEmpty && sessions.isEmpty && competitions.isEmpty)
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
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundColor(.white)

            LessonPrioritiesSection()

            if remindersBlocked { remindersCard }

            trainingsSection

            if let comp = nextCompetition {
                competitionCard(comp)
            }

            PlannerWeekSummary(cadences: cadences, sessions: sessions, logs: logs)

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
        .fullScreenCover(item: $competitionDay) { CompetitionDayView(competition: $0) }
        .sheet(isPresented: $showPaywall) { SubscriptionPaywallView(initialTier: .plus) }
    }

    // MARK: Trainings
    @ViewBuilder
    private var trainingsSection: some View {
        if cadences.isEmpty && sessions.isEmpty && todaysTrainings.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Nastav si týždenný režim")
                    .font(.callout.weight(.bold))
                    .foregroundColor(.white)
                Text("Raz zadáš, kedy trénuješ. Potom ti stačí v daný deň ťuknúť Idem alebo Nejdem a po tréningu zapísať, čo nové sa ti podarilo.")
                    .font(.footnote)
                    .foregroundColor(Color.white.opacity(0.6))
                Button(action: onOpenRoutine) {
                    Text("Nastaviť režim")
                        .font(.subheadline.weight(.bold))
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
                    .font(.callout.weight(.bold))
                    .foregroundColor(.white)
                if let next = nextTraining {
                    Text(nextTrainingText(next))
                        .font(.footnote)
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
                    onDebrief: { debriefEntry = occurrence.entryCreatingIfNeeded(in: logs, context: modelContext) },
                    onEdit: {
                        switch occurrence.source {
                        case .weekly(let cadence): editingCadence = cadence
                        case .session(let session): editingSession = session
                        case .recorded(let entry): debriefEntry = entry
                        }
                    }
                )
            }
        }
    }

    private func setStatus(_ status: TrainingStatus, for occurrence: TrainingOccurrence) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            occurrence.setStatus(status, logs: logs, context: modelContext)
        }
        changeTick += 1
    }

    // MARK: Reminders off
    private var remindersCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.headline)
                .foregroundColor(Color.gold400)
            VStack(alignment: .leading, spacing: 8) {
                Text("Pripomienky sú vypnuté")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Text("Nepríde ti výzva na reflexiu po tréningu ani pripomienka uzávierky prihlášok.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                Button("Zapnúť pripomienky", action: enableReminders)
                    .font(.footnote.weight(.bold))
                    .foregroundColor(Color.gold400)
                    .frame(minHeight: 44)
                    .buttonStyle(.pressable)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plannerCard()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// First time: the system question. Refused before: only Settings can change it.
    private func enableReminders() {
        Task {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            if status == .notDetermined {
                _ = await notifications.requestAuthorization()
            } else if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
        }
    }

    // MARK: Competition
    private func competitionCard(_ comp: PlannedCompetition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            plannerSectionTitle("NAJBLIŽŠIA SÚŤAŽ")
            HStack(alignment: .firstTextBaseline) {
                Text("\(PlannerCalendar.daysText(until: comp.date)) — \(comp.name)")
                    .font(.callout.weight(.bold))
                    .foregroundColor(.white)
                Spacer(minLength: 8)
                Text(comp.intent.title)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(comp.intent == .going ? Color.obsidian900 : Color.gold300)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(comp.intent == .going ? Color.gold400 : Color.gold500.opacity(0.14), in: Capsule())
            }
            if !comp.city.isEmpty {
                Text(comp.city)
                    .font(.footnote)
                    .foregroundColor(Color.white.opacity(0.6))
            }
            if let deadline = comp.entryDeadline,
               PlannerCalendar.startOfDay(deadline) >= today,
               (PlannerCalendar.calendar.dateComponents([.day], from: today, to: PlannerCalendar.startOfDay(deadline)).day ?? 99) <= 7 {
                Label("Uzávierka prihlášok: \(deadline.formatted(.dateTime.weekday(.wide).day().month()))",
                      systemImage: "exclamationmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.latinCrimson)
            }
            // The day before and on the day: the dances with the coach's Top 3 (Plus).
            if (0...1).contains(PlannerCalendar.calendar.dateComponents([.day], from: today, to: PlannerCalendar.startOfDay(comp.date)).day ?? -1) {
                competitionDayButton(comp)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plannerCard()
    }

    private func competitionDayButton(_ comp: PlannedCompetition) -> some View {
        let hasPlus = subscriptionManager.currentTier >= .plus
        return Button {
            if hasPlus { competitionDay = comp } else { showPaywall = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: hasPlus ? "list.number" : "lock.fill")
                Text("Súťažný deň: tance a tvoje Top 3")
                Spacer(minLength: 0)
                if !hasPlus {
                    Text("PLUS")
                        .font(.system(.caption2, design: .rounded).weight(.black))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.obsidian900.opacity(0.2), in: Capsule())
                }
            }
            .font(.subheadline.weight(.bold))
            .foregroundColor(Color.obsidian900)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Color.gold400, in: Capsule())
        }
        .buttonStyle(.pressable)
        .padding(.top, 4)
    }

    private func reflectionRow(_ entry: TrainingLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.feeling?.emoji ?? "📝")
                Text(entry.title.isEmpty ? "Tréning" : entry.title)
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.white)
                Spacer()
                Text(entry.day, format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
                    .foregroundColor(Color.white.opacity(0.4))
            }
            Text(entry.reflectionNote)
                .font(.footnote)
                .foregroundColor(Color.white.opacity(0.75))
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plannerCard(cornerRadius: 14)
    }
}

// MARK: - This week
/// Hours trained this week against the plan, how much of it was samotréning, and the dance worked on most
/// (from the reflections). A training counts once it has ended and was not cancelled.
struct PlannerWeekSummary: View {
    let cadences: [TrainingCadence]
    let sessions: [PlannedSession]
    let logs: [TrainingLogEntry]

    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showTrends = false
    @State private var showPaywall = false

    private struct Totals: Equatable {
        var doneMinutes = 0
        var plannedMinutes = 0
        var soloMinutes = 0
        var topDance: String?
    }

    private var totals: Totals {
        let cal = PlannerCalendar.calendar
        let now = Date()
        let today = PlannerCalendar.startOfDay(now)
        let monday = cal.date(byAdding: .day, value: 1 - PlannerCalendar.isoWeekday(of: today), to: today) ?? today
        var totals = Totals()
        var entryIds = Set<UUID>()
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: monday) else { continue }
            for occurrence in TrainingOccurrence.on(day, cadences: cadences, sessions: sessions, logs: logs) {
                let entry = occurrence.entry(in: logs)
                guard entry?.status != .skipped else { continue }
                let minutes = Int(occurrence.end.timeIntervalSince(occurrence.start) / 60)
                totals.plannedMinutes += minutes
                guard occurrence.end <= now else { continue }
                totals.doneMinutes += minutes
                if occurrence.isSolo { totals.soloMinutes += minutes }
                if let entry { entryIds.insert(entry.id) }
            }
        }
        let dances = logs.filter { entryIds.contains($0.id) }.compactMap(\.danceName)
        totals.topDance = Dictionary(grouping: dances, by: { $0 }).max { $0.value.count < $1.value.count }?.key
        return totals
    }

    var body: some View {
        let totals = totals
        if totals.plannedMinutes > 0 {
            VStack(alignment: .leading, spacing: 10) {
                HomeSectionHeader(title: "TENTO TÝŽDEŇ", systemImage: "chart.bar.fill")
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        tile(hours(totals.doneMinutes), "z \(hours(totals.plannedMinutes)) odtrénované")
                        tile(hours(totals.soloMinutes), "samotréning")
                        tile(totals.topDance.map(DanceNames.display) ?? "–", "najviac riešené")
                    }
                    progressBar(done: totals.doneMinutes, planned: totals.plannedMinutes)
                    trendsButton
                }
                .padding(14)
                .homeCard(cornerRadius: 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.85), value: totals)
            }
            .sheet(isPresented: $showTrends) { TrainingTrendsView(cadences: cadences, sessions: sessions, logs: logs) }
            .sheet(isPresented: $showPaywall) { SubscriptionPaywallView(initialTier: .plus) }
        }
    }

    /// Weeks and months behind this week (Plus).
    private var trendsButton: some View {
        let hasPlus = subscriptionManager.currentTier >= .plus
        return Button {
            if hasPlus { showTrends = true } else { showPaywall = true }
        } label: {
            HStack(spacing: 6) {
                Text("Vývoj za mesiac a sezónu")
                if !hasPlus {
                    Text("PLUS")
                        .font(.system(.caption2, design: .rounded).weight(.black))
                        .foregroundColor(Color.obsidian900)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gold400, in: Capsule())
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
            .font(.footnote.weight(.bold))
            .foregroundColor(Color.gold400)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.98))
    }

    private func tile(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundColor(Color.gold300)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            Text(caption)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func progressBar(done: Int, planned: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * min(1, CGFloat(done) / CGFloat(max(planned, 1))))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    /// "4,5 h", "45 min".
    private func hours(_ minutes: Int) -> String {
        if minutes > 0 && minutes < 60 { return "\(minutes) min" }
        let value = Double(minutes) / 60
        return "\(value.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "sk")))) h"
    }
}
