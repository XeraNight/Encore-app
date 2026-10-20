import SwiftUI
import SwiftData

// MARK: - One training on one day
/// A weekly training on a concrete day, a one-off training, or a recorded day whose training is gone.
/// Shared by Dnes and Kalendár.
struct TrainingOccurrence: Identifiable {
    enum Source {
        case weekly(TrainingCadence)
        case session(PlannedSession)
        /// A reflection whose training was deleted or moved to another weekday: it stays on its day.
        case recorded(TrainingLogEntry)
    }

    let source: Source
    /// Start of the day.
    let day: Date

    /// Days back a weekly training still shows without anything recorded, so a forgotten reflection
    /// or "Vynechať" can be filled in. Older days show only what was recorded.
    static let missedDays = 7

    var id: String {
        switch source {
        case .weekly(let cadence): return "w\(cadence.id.uuidString)\(Int(day.timeIntervalSince1970))"
        case .session(let session): return "s\(session.id.uuidString)"
        case .recorded(let entry): return "r\(entry.id.uuidString)"
        }
    }

    /// A recorded day has no time any more (its training is gone).
    var hasTime: Bool {
        if case .recorded = source { return false }
        return true
    }

    var start: Date {
        switch source {
        case .weekly(let cadence): return PlannerCalendar.date(on: day, minutes: cadence.startMinutes)
        case .session(let session): return session.start
        case .recorded: return day
        }
    }

    var end: Date {
        switch source {
        case .weekly(let cadence): return PlannerCalendar.date(on: day, minutes: cadence.endMinutes)
        case .session(let session): return session.end
        case .recorded: return day
        }
    }

    var title: String {
        switch source {
        case .weekly(let cadence): return cadence.title.isEmpty ? "Tréning" : cadence.title
        case .session(let session): return session.displayTitle
        case .recorded(let entry): return entry.title.isEmpty ? "Tréning" : entry.title
        }
    }

    var kindTitle: String {
        switch source {
        case .weekly: return "Každý týždeň"
        case .session(let session): return session.kind.title
        case .recorded: return "Zapísané"
        }
    }

    var location: String {
        switch source {
        case .weekly(let cadence): return cadence.location
        case .session(let session): return session.location
        case .recorded: return ""
        }
    }

    var goal: String? {
        guard case .session(let session) = source, !session.goal.isEmpty else { return nil }
        return session.goal
    }

    var goalOutcome: SessionGoalOutcome? {
        guard case .session(let session) = source else { return nil }
        return session.goalOutcome
    }

    var isSolo: Bool {
        if case .session(let session) = source { return session.kind == .solo }
        return false
    }

    /// Dot in the calendar: white for weekly trainings, gold for one-off ones.
    var dotColor: Color {
        switch source {
        case .weekly, .recorded: return .white.opacity(0.85)
        case .session: return Color.gold400
        }
    }

    func entry(in logs: [TrainingLogEntry]) -> TrainingLogEntry? {
        switch source {
        case .weekly(let cadence): return PlannerAttendance.entry(cadence: cadence, on: day, in: logs)
        case .session(let session): return PlannerAttendance.entry(session: session, in: logs)
        case .recorded(let entry): return entry
        }
    }

    func entryCreatingIfNeeded(in logs: [TrainingLogEntry], context: ModelContext) -> TrainingLogEntry {
        switch source {
        case .weekly(let cadence):
            return PlannerAttendance.entryCreatingIfNeeded(cadence: cadence, on: day, in: logs, context: context)
        case .session(let session):
            return PlannerAttendance.entryCreatingIfNeeded(session: session, in: logs, context: context)
        case .recorded(let entry):
            return entry
        }
    }

    func setStatus(_ status: TrainingStatus, logs: [TrainingLogEntry], context: ModelContext) {
        switch source {
        case .weekly(let cadence):
            PlannerAttendance.setStatus(status, cadence: cadence, on: day, logs: logs, context: context)
        case .session(let session):
            PlannerAttendance.setStatus(status, session: session, logs: logs, context: context)
        case .recorded:
            break
        }
    }

    /// Trainings of one day. Weekly trainings show from today on and for the last `missedDays` days (since the
    /// training exists); further back only where something was recorded. A reflection stays on its day even
    /// when its training was deleted or moved.
    /// `wholePast` (trends): a weekly training counts on every past day since it was added, not only
    /// the last `missedDays`.
    static func on(_ day: Date, cadences: [TrainingCadence], sessions: [PlannedSession],
                   logs: [TrainingLogEntry], wholePast: Bool = false) -> [TrainingOccurrence] {
        let cal = PlannerCalendar.calendar
        let date = cal.startOfDay(for: day)
        let today = cal.startOfDay(for: Date())
        let recentStart = wholePast ? Date.distantPast : (cal.date(byAdding: .day, value: -missedDays, to: today) ?? today)
        let weekday = PlannerCalendar.isoWeekday(of: date)
        var list: [TrainingOccurrence] = []
        for cadence in cadences where cadence.weekday == weekday {
            let recorded = PlannerAttendance.entry(cadence: cadence, on: date, in: logs) != nil
            let scheduled = cadence.isEnabled && date >= recentStart && date >= cal.startOfDay(for: cadence.createdAt)
            if scheduled || recorded {
                list.append(TrainingOccurrence(source: .weekly(cadence), day: date))
            }
        }
        for session in sessions where cal.isDate(session.start, inSameDayAs: date) {
            list.append(TrainingOccurrence(source: .session(session), day: date))
        }

        let shown = Set(list.compactMap { $0.entry(in: logs)?.id })
        let sessionIds = Set(sessions.map(\.id))
        for entry in logs where entry.status == .attended && !shown.contains(entry.id)
            && cal.isDate(entry.day, inSameDayAs: date) {
            // A one-off training that still exists shows its reflection on the training's own day.
            if let sessionId = entry.sessionId, sessionIds.contains(sessionId) { continue }
            list.append(TrainingOccurrence(source: .recorded(entry), day: date))
        }
        return list.sorted { $0.start < $1.start }
    }
}

// MARK: - Training card
/// Time, title and place; Nejdem before the end, the reflection after it. A cancelled training is crossed
/// out and can be restored.
struct TrainingOccurrenceCard: View {
    let occurrence: TrainingOccurrence
    let entry: TrainingLogEntry?
    let onSetStatus: (TrainingStatus) -> Void
    let onDebrief: () -> Void
    let onEdit: () -> Void

    private var status: TrainingStatus { entry?.status ?? .planned }
    private var hasEnded: Bool { Date() > occurrence.end }
    private var isCancelled: Bool { status == .skipped }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onEdit) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        if occurrence.hasTime {
                            Text("\(occurrence.start.formatted(date: .omitted, time: .shortened)) – \(occurrence.end.formatted(date: .omitted, time: .shortened))")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundColor(Color.gold400)
                        }
                        Text(occurrence.title)
                            .font(.headline)
                            .foregroundColor(.white.opacity(isCancelled ? 0.5 : 1))
                            .strikethrough(isCancelled, color: Color.latinRed)
                        if !occurrence.location.isEmpty {
                            Label(occurrence.location, systemImage: "mappin.and.ellipse")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        if let goal = occurrence.goal {
                            Label(goal, systemImage: "target")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(Color.gold300.opacity(isCancelled ? 0.5 : 0.9))
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(occurrence.kindTitle)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(Color.gold300)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.gold500.opacity(0.14), in: Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(scale: 0.98))
            .accessibilityHint(occurrence.hasTime ? "Upraviť tréning" : "Upraviť reflexiu")

            actions
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 20)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: status)
    }

    @ViewBuilder
    private var actions: some View {
        switch status {
        case .planned, .going:
            // A training counts unless cancelled, so there is nothing to confirm before it: only "Nejdem".
            if hasEnded {
                HStack(spacing: 10) {
                    pill("Zapísať reflexiu", icon: "square.and.pencil", filled: true, action: onDebrief)
                    pill("Vynechať", icon: "xmark", filled: false) { onSetStatus(.skipped) }
                }
            } else {
                HStack {
                    Spacer()
                    smallButton("Nejdem", color: .white.opacity(0.7)) { onSetStatus(.skipped) }
                }
            }
        case .skipped:
            HStack {
                Label("Zrušené", systemImage: "calendar.badge.minus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                smallButton("Vrátiť", color: Color.gold400) { onSetStatus(.planned) }
            }
        case .attended:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Label("Reflexia uložená", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color.syncEmerald)
                    if let feeling = entry?.feeling { Text(feeling.emoji) }
                    if let outcome = occurrence.goalOutcome {
                        Text(outcome.title)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(Color.obsidian900)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.gold400, in: Capsule())
                    }
                    Spacer()
                    smallButton("Upraviť", color: Color.gold400, action: onDebrief)
                }
                if let note = entry?.reflectionNote, !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(3)
                }
            }
        }
    }

    private func pill(_ title: String, icon: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .foregroundColor(filled ? Color.obsidian900 : .white.opacity(0.85))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 44)
                .background(filled ? Color.gold400 : Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.pressable)
    }

    private func smallButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.footnote.weight(.semibold))
            .foregroundColor(color)
            .frame(minHeight: 44)
            .buttonStyle(.pressable)
    }
}

// MARK: - Kalendár → Mesiac
/// Everything on one calendar: trainings (white dot weekly, gold dot one-off), planned competitions (dashed
/// ring), danced competitions from KSIS (ring, filled for a podium). The tapped day lists its trainings,
/// competitions, results and the notes written that day; "+" adds to that day.
struct PlannerCalendarView: View {
    let cadences: [TrainingCadence]
    let logs: [TrainingLogEntry]
    let competitions: [PlannedCompetition]
    let sessions: [PlannedSession]
    var onOpenRoutine: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var results = CompetitionManager.shared
    @Query(sort: \InstantNote.createdAt) private var notes: [InstantNote]

    @State private var month = MonthCalendarCard.startOfMonth(Date())
    @State private var selectedDay: Date? = PlannerCalendar.startOfDay(Date())
    @State private var adding: NewPlanItem?
    @State private var editingCompetition: PlannedCompetition?
    @State private var editingSession: PlannedSession?
    @State private var editingCadence: TrainingCadence?
    @State private var debriefEntry: TrainingLogEntry?
    @State private var openNote: InstantNote?
    @State private var openResult: CompetitionResult?
    @State private var browser: KSISBrowserTarget?
    @State private var changeTick = 0

    private static let calendar = PlannerCalendar.calendar

    var body: some View {
        let resultsByDay = self.resultsByDay
        VStack(alignment: .leading, spacing: 18) {
            MonthCalendarCard(
                month: $month,
                selectedDay: $selectedDay,
                mark: { mark(for: $0, resultsByDay: resultsByDay) },
                legend: [
                    (CalendarDayMark(dots: [.white]), "Tréning"),
                    (CalendarDayMark(dots: [Color.gold400]), "Samotréning"),
                    (CalendarDayMark(ring: .dashed), "Súťaž"),
                    (CalendarDayMark(ring: .solid), "Výsledok"),
                ],
                selectsEmptyDays: true,
                deselectsOnSecondTap: false
            )

            if let day = selectedDay {
                dayAgenda(day, results: resultsByDay[day] ?? [])
                    .id(day)
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.86), value: selectedDay)
        .onChange(of: month) { _, newMonth in
            if selectedDay == nil || !Self.calendar.isDate(selectedDay ?? newMonth, equalTo: newMonth, toGranularity: .month) {
                let today = PlannerCalendar.startOfDay(Date())
                selectedDay = Self.calendar.isDate(today, equalTo: newMonth, toGranularity: .month) ? today : newMonth
            }
        }
        .sensoryFeedback(.selection, trigger: changeTick)
        .task { if results.results.isEmpty { await results.loadAllData() } }
        .onChange(of: results.results.map(\.id), initial: true) { _, _ in
            PlannedCompetition.linkDanced(competitions, to: results.results, context: modelContext)
        }
        .sheet(item: $adding) { item in
            switch item.kind {
            case .solo: SessionEditorSheet(session: nil, initialDate: item.day, initialKind: .solo)
            case .lesson: SessionEditorSheet(session: nil, initialDate: item.day, initialKind: .lesson)
            case .competition: CompetitionEditorSheet(competition: nil, initialDate: item.day)
            case .weekly: CadenceEditorSheet(cadence: nil, initialWeekday: PlannerCalendar.isoWeekday(of: item.day))
            }
        }
        .sheet(item: $editingCompetition) { CompetitionEditorSheet(competition: $0) }
        .sheet(item: $editingSession) { SessionEditorSheet(session: $0) }
        .sheet(item: $editingCadence) { CadenceEditorSheet(cadence: $0) }
        .sheet(item: $debriefEntry) { DebriefSheet(entry: $0).presentationDetents([.large]) }
        .sheet(item: $openNote) { NoteDetailSheet(note: $0) }
        .sheet(item: $openResult) { result in
            KSISResultDetailView(result: result) { url in
                openResult = nil
                browser = KSISBrowserTarget(url: url)
            }
        }
        .fullScreenCover(item: $browser) { KSISBrowserView(startURL: $0.url) }
    }

    // MARK: Day

    private func dayAgenda(_ day: Date, results dayResults: [CompetitionResult]) -> some View {
        let trainings = TrainingOccurrence.on(day, cadences: cadences, sessions: sessions, logs: logs)
        let dayCompetitions = competitions.filter { Self.calendar.isDate($0.date, inSameDayAs: day) }
        let dayNotes = notes(on: day)
        let isEmpty = trainings.isEmpty && dayCompetitions.isEmpty && dayResults.isEmpty && dayNotes.isEmpty

        return VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: dayTitle(day), systemImage: "calendar") {
                addMenu(day)
            }

            if isEmpty {
                emptyDay(day)
            }

            ForEach(dayResults) { result in
                Button { openResult = result } label: { CompetitionResultRow(result: result) }
                    .buttonStyle(.pressable(scale: 0.98))
                    .homeCard(cornerRadius: 20)
            }

            ForEach(dayCompetitions) { competition in
                competitionRow(competition)
            }

            ForEach(trainings) { occurrence in
                TrainingOccurrenceCard(
                    occurrence: occurrence,
                    entry: occurrence.entry(in: logs),
                    onSetStatus: { setStatus($0, for: occurrence) },
                    onDebrief: { debriefEntry = occurrence.entryCreatingIfNeeded(in: logs, context: modelContext) },
                    onEdit: { edit(occurrence) }
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            if !dayNotes.isEmpty {
                notesList(dayNotes)
            }
        }
    }

    private func addMenu(_ day: Date) -> some View {
        Menu {
            Button { adding = NewPlanItem(kind: .solo, day: day) } label: { Label("Samotréning", systemImage: "figure.dance") }
            Button { adding = NewPlanItem(kind: .lesson, day: day) } label: { Label("Lekcia", systemImage: "person.2.fill") }
            Button { adding = NewPlanItem(kind: .competition, day: day) } label: { Label("Súťaž", systemImage: "trophy.fill") }
            Button { adding = NewPlanItem(kind: .weekly, day: day) } label: { Label("Týždenný tréning", systemImage: "repeat") }
        } label: {
            Label("Pridať", systemImage: "plus")
                .font(.caption.weight(.bold))
                .foregroundColor(Color.obsidian900)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gold400, in: Capsule())
                .frame(minHeight: 44)
        }
        .accessibilityIdentifier("plan.calendar.add")
    }

    @ViewBuilder
    private func emptyDay(_ day: Date) -> some View {
        if Self.calendar.isDateInToday(day) {
            emptyToday
        } else {
            emptyOtherDay(day)
        }
    }

    /// Nothing planned at all: set the weekly rhythm once. Otherwise a free day and when the next training is.
    @ViewBuilder
    private var emptyToday: some View {
        if cadences.isEmpty && sessions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Nastav si týždenný režim")
                    .font(.callout.weight(.bold))
                    .foregroundColor(.white)
                Text("Raz zadáš, kedy trénuješ. Ak v daný deň nejdeš, ťukneš Nejdem, a po tréningu zapíšeš, čo nové sa ti podarilo.")
                    .font(.footnote)
                    .foregroundColor(Color.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
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
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCard(cornerRadius: 20)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Dnes máš voľno")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                if let next = nextTraining {
                    Text(nextTrainingText(next))
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCard(cornerRadius: 20)
        }
    }

    /// The next training after today that is not cancelled, weekly or one-off, within two weeks.
    private var nextTraining: TrainingOccurrence? {
        let today = PlannerCalendar.startOfDay(Date())
        for offset in 1...14 {
            guard let day = Self.calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if let next = TrainingOccurrence.on(day, cadences: cadences, sessions: sessions, logs: logs)
                .first(where: { $0.hasTime && $0.entry(in: logs)?.status != .skipped }) {
                return next
            }
        }
        return nil
    }

    private func nextTrainingText(_ next: TrainingOccurrence) -> String {
        let day = Self.calendar.isDateInTomorrow(next.day)
            ? "Zajtra"
            : PlannerCalendar.weekdayName(iso: PlannerCalendar.isoWeekday(of: next.day))
        return "Najbližší tréning: \(day) \(next.start.formatted(date: .omitted, time: .shortened)), \(next.title)"
    }

    private func emptyOtherDay(_ day: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(day < PlannerCalendar.startOfDay(Date()) ? "V tento deň nič nie je zapísané" : "Voľný deň")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
            Text("Cez Pridať sem dáš samotréning, lekciu alebo súťaž. Aj spätne, napríklad tréning navyše.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 20)
    }

    private func competitionRow(_ competition: PlannedCompetition) -> some View {
        Button { editingCompetition = competition } label: {
            HStack(spacing: 12) {
                Image(systemName: competition.isTargetCompetition ? "star.circle.fill" : "trophy.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color.gold400)
                VStack(alignment: .leading, spacing: 3) {
                    Text(competition.name)
                        .font(.headline)
                        .foregroundColor(.white.opacity(competition.intent == .declined ? 0.5 : 1))
                        .strikethrough(competition.intent == .declined, color: Color.latinRed)
                    Text([competition.city, competition.targetCategories.joined(separator: " · ")]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer(minLength: 8)
                if let place = competition.dancedPlaceLine(in: results.results) {
                    DancedPlaceChip(place: place)
                } else {
                    Text(competition.intent.title)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(competition.intent == .going ? Color.obsidian900 : Color.gold300)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(competition.intent == .going ? Color.gold400 : Color.gold500.opacity(0.14), in: Capsule())
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCard(cornerRadius: 20)
        }
        .buttonStyle(.pressable(scale: 0.98))
    }

    private func notesList(_ dayNotes: [InstantNote]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "POZNÁMKY Z TOHTO DŇA", systemImage: "note.text", count: dayNotes.count)
            VStack(spacing: 0) {
                ForEach(dayNotes) { note in
                    Button { openNote = note } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: note.kindIcon)
                                .font(.caption.weight(.bold))
                                .foregroundColor(Color.gold400)
                                .frame(width: 20)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 3) {
                                if let dance = note.danceName {
                                    Text(DanceNames.display(dance).uppercased())
                                        .font(.system(.caption2, design: .rounded).weight(.black))
                                        .foregroundColor(Color.gold400)
                                        .tracking(1)
                                }
                                Text(note.previewText)
                                    .font(.footnote.weight(.medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(4)
                            }
                            Spacer(minLength: 8)
                            Text(note.createdAt.formatted(date: .omitted, time: .shortened))
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable(scale: 0.98))
                    if note.id != dayNotes.last?.id { HomeRowDivider() }
                }
            }
            .homeCard(cornerRadius: 20)
        }
        .padding(.top, 4)
    }

    // MARK: Actions

    private func setStatus(_ status: TrainingStatus, for occurrence: TrainingOccurrence) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            occurrence.setStatus(status, logs: logs, context: modelContext)
        }
        changeTick += 1
    }

    private func edit(_ occurrence: TrainingOccurrence) {
        switch occurrence.source {
        case .weekly(let cadence): editingCadence = cadence
        case .session(let session): editingSession = session
        case .recorded(let entry): debriefEntry = entry
        }
    }

    // MARK: Data

    private func mark(for day: Date, resultsByDay: [Date: [CompetitionResult]]) -> CalendarDayMark {
        var mark = CalendarDayMark(ring: CompetitionResult.calendarMark(for: resultsByDay[day] ?? []).ring)
        if mark.ring == nil,
           competitions.contains(where: { $0.intent != .declined && Self.calendar.isDate($0.date, inSameDayAs: day) }) {
            mark.ring = .dashed
        }
        mark.dots = TrainingOccurrence.on(day, cadences: cadences, sessions: sessions, logs: logs)
            .filter { $0.entry(in: logs)?.status != .skipped }
            .map(\.dotColor)
        return mark
    }

    private var resultsByDay: [Date: [CompetitionResult]] {
        var byDay: [Date: [CompetitionResult]] = [:]
        for result in results.results {
            guard let date = result.dateValue else { continue }
            byDay[Self.calendar.startOfDay(for: date), default: []].append(result)
        }
        return byDay
    }

    /// Notes written that day. A reflection is already shown on its training card, so it is left out here.
    private func notes(on day: Date) -> [InstantNote] {
        let reflectionNotes = Set(logs.compactMap(\.noteId))
        return notes.filter { Self.calendar.isDate($0.createdAt, inSameDayAs: day) && !reflectionNotes.contains($0.id) }
    }

    private func dayTitle(_ day: Date) -> String {
        if Self.calendar.isDateInToday(day) { return "DNES" }
        if Self.calendar.isDateInTomorrow(day) { return "ZAJTRA" }
        if Self.calendar.isDateInYesterday(day) { return "VČERA" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "sk"))).uppercased()
    }
}

/// What "Pridať" opens, and for which day.
struct NewPlanItem: Identifiable {
    enum Kind { case solo, lesson, competition, weekly }
    let kind: Kind
    let day: Date
    var id: String { "\(kind)\(day.timeIntervalSince1970)" }
}
