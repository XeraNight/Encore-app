import AVFoundation
import SwiftData
import SwiftUI

// MARK: - Denník (all notes)
/// Every note by day, like a training journal (BRAND_GUIDELINES §1A): a strip of days, the day's notes as
/// glass cards with a short voice note right inside the sentence, "Počúvať" plays the day's voice notes one
/// after another, and Hlas | Text writes a new note in a card that comes up while the rest blurs.
struct TrainingJournalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \InstantNote.createdAt) private var notes: [InstantNote]
    @Query(sort: \TrainingCadence.startMinutes) private var cadences: [TrainingCadence]
    @Query(sort: \PlannedSession.start) private var sessions: [PlannedSession]
    @Query(sort: \TrainingLogEntry.day, order: .reverse) private var logs: [TrainingLogEntry]

    @StateObject private var player = VoiceNotePlayer()
    @State private var selectedDay: Date?
    @State private var mode: JournalMode = .read
    @State private var listeningId: UUID?
    @State private var composer: JournalComposer.Kind?
    @State private var composerDance: String?
    @State private var search = ""
    @State private var noteToEdit: InstantNote?
    @State private var noteForFigure: InstantNote?
    @State private var noteToDelete: InstantNote?
    @State private var figureNames: [UUID: String] = [:]
    @State private var toast: String?
    @State private var savedTick = 0
    @Namespace private var dayNamespace

    enum JournalMode: Hashable { case read, listen }

    private var calendar: Calendar { PlannerCalendar.calendar }

    /// Days that have notes, oldest first (the strip reads left to right like a calendar).
    private var days: [Date] {
        var seen = Set<Date>()
        return notes.map { calendar.startOfDay(for: $0.createdAt) }.filter { seen.insert($0).inserted }
    }

    private var day: Date? { selectedDay ?? days.last }

    private var dayNotes: [InstantNote] {
        guard let day else { return [] }
        return notes.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
    }

    private var searchResults: [InstantNote] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return notes.reversed().filter { $0.text.lowercased().contains(query) }
    }

    private var isSearching: Bool { !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var voiceNotes: [InstantNote] { dayNotes.filter { $0.audioPath != nil } }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                content
                    .blur(radius: composer == nil || reduceMotion ? 0 : 8)
                    .scaleEffect(composer == nil || reduceMotion ? 1 : 0.95)
                    .allowsHitTesting(composer == nil)
                if composer != nil {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture { composer = nil }
                        .transition(.opacity)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let kind = composer {
                    JournalComposer(kind: kind, dance: $composerDance, onSave: save, onClose: { composer = nil })
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .scale(scale: 0.8, anchor: .bottom)).combined(with: .opacity))
                } else if !isSearching {
                    bottomBar
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .top) { toastView }
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82), value: composer)
            .navigationTitle("Denník")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Hľadať v denníku")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Hotovo") { dismiss() } }
            }
            .sheet(item: $noteToEdit) { NoteDetailSheet(note: $0) }
            .sheet(item: $noteForFigure) { note in
                FigurePickerSheet(note: note) { showToast("Pridané k figúre") }
            }
            .confirmationDialog("Zmazať poznámku?", isPresented: Binding(get: { noteToDelete != nil }, set: { if !$0 { noteToDelete = nil } }),
                                titleVisibility: .visible, presenting: noteToDelete) { note in
                Button("Zmazať", role: .destructive) { delete(note) }
                Button("Ponechať", role: .cancel) {}
            } message: { note in
                Text(note.audioPath != nil ? "Zmaže sa aj hlasovka. Nedá sa to vrátiť." : "Nedá sa to vrátiť.")
            }
            .sensoryFeedback(.selection, trigger: selectedDay)
            .sensoryFeedback(.selection, trigger: mode)
            .sensoryFeedback(.success, trigger: savedTick)
            .environment(\.locale, Locale(identifier: "sk"))
            .task(id: notes.compactMap(\.linkedFigureId)) { loadFigureNames() }
            .onChange(of: mode) { _, newMode in newMode == .listen ? startListening() : stopListening() }
            .onChange(of: selectedDay) { _, _ in if mode == .listen { mode = .read } }
            .onDisappear { stopListening() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Content
    @ViewBuilder
    private var content: some View {
        if notes.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isSearching {
                        HomeSectionHeader(title: "VÝSLEDKY", systemImage: "magnifyingglass", count: searchResults.count)
                        ForEach(searchResults) { card(for: $0, showsDate: true) }
                    } else {
                        dayStrip
                        dayHeader
                        ForEach(dayNotes) { card(for: $0, showsDate: false) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.82), value: dayNotes.map(\.id))
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "book.pages")
                .font(.largeTitle)
                .foregroundColor(Color.gold400)
            Text("Tvoj tréningový denník")
                .font(.headline)
                .foregroundColor(.white)
            Text("Ťukni na Hlas alebo Text a zapíš, čo si chceš z tréningu zapamätať. Poznámky sa tu zoradia podľa dní.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .homeCard(cornerRadius: 20)
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity)
    }

    // MARK: Days
    private var dayStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(days, id: \.self) { date in dayCapsule(date) }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
            .onAppear { if let day { proxy.scrollTo(day, anchor: .trailing) } }
        }
    }

    private func dayCapsule(_ date: Date) -> some View {
        let isOn = day.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { selectedDay = date }
        } label: {
            VStack(spacing: 1) {
                Text(date, format: .dateTime.weekday(.abbreviated))
                    .font(.caption2.weight(.semibold))
                Text(date, format: .dateTime.day())
                    .font(.system(.headline, design: .rounded).weight(.bold))
            }
            .foregroundColor(isOn ? Color.obsidian900 : .white.opacity(0.8))
            .frame(width: 46, height: 52)
            .background {
                ZStack {
                    Capsule().fill(Color.white.opacity(0.05))
                    if isOn {
                        Capsule().fill(Color.gold400).matchedGeometryEffect(id: "day", in: dayNamespace)
                    }
                }
            }
            .overlay(Capsule().stroke(isOn ? Color.gold400.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.pressable(scale: 0.92))
        .id(date)
        .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: Day header
    private var dayHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeSectionHeader(title: trainingTitle, systemImage: "figure.dance",
                              count: nil) {
                Text(slovakCount(dayNotes.count, one: "poznámka", few: "poznámky", many: "poznámok"))
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.6))
                    .contentTransition(.numericText())
            }
            if let day {
                Text(day, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .foregroundColor(.white)
            }
            let dances = Array(Set(dayNotes.compactMap(\.danceName))).sorted { DanceNames.rank($0) < DanceNames.rank($1) }
            if !dances.isEmpty {
                HStack(spacing: 10) {
                    ForEach(dances, id: \.self) { dance in
                        HStack(spacing: 5) {
                            Circle().fill(disciplineColor(dance))
                                .frame(width: 7, height: 7)
                            Text(DanceNames.display(dance))
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                    }
                }
            }
        }
    }

    /// "TRÉNING 18:00" when the Kalendár has a training that day (the one closest to the notes).
    private var trainingTitle: String {
        guard let day, let first = dayNotes.first else { return "POZNÁMKY" }
        let trainings = TrainingOccurrence.on(day, cadences: cadences, sessions: sessions, logs: logs, wholePast: true)
        guard let training = trainings.min(by: { abs($0.start.timeIntervalSince(first.createdAt)) < abs($1.start.timeIntervalSince(first.createdAt)) })
        else { return "POZNÁMKY" }
        let time = training.hasTime ? " " + training.start.formatted(date: .omitted, time: .shortened) : ""
        return training.title.uppercased() + time
    }

    // MARK: Cards
    private func card(for note: InstantNote, showsDate: Bool) -> some View {
        JournalNoteCard(
            note: note,
            figureName: note.linkedFigureId.flatMap { figureNames[$0] },
            showsDate: showsDate,
            isListening: listeningId == note.id,
            player: player,
            onAddToFigure: { noteForFigure = note }
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { noteToEdit = note }
        .contextMenu {
            Button { togglePin(note) } label: {
                Label(note.isPinned ? "Odopnúť" : "Pripnúť", systemImage: note.isPinned ? "pin.slash" : "pin")
            }
            if note.isImported {
                Button { restore(note) } label: { Label("Vrátiť medzi nové", systemImage: "arrow.uturn.backward") }
            } else if note.hasText {
                Button { noteForFigure = note } label: { Label("Pridať k figúre", systemImage: "plus.circle") }
            }
            Button(role: .destructive) { noteToDelete = note } label: { Label("Zmazať", systemImage: "trash") }
        }
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }

    // MARK: Bottom bar
    private var bottomBar: some View {
        VStack(spacing: 10) {
            if voiceNotes.count > 1 {
                PlannerChoice(options: [(JournalMode.read, "Čítať"), (.listen, "Počúvať")], selection: $mode)
            }
            HStack(spacing: 0) {
                newNoteButton(title: "Hlas", systemImage: "mic.fill", kind: .voice)
                Rectangle().fill(Color.obsidian900.opacity(0.2)).frame(width: 1, height: 24)
                newNoteButton(title: "Text", systemImage: "square.and.pencil", kind: .text)
            }
            .frame(height: 52)
            .background(Color.gold400, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func newNoteButton(title: String, systemImage: String, kind: JournalComposer.Kind) -> some View {
        Button {
            mode = .read
            composerDance = dayNotes.last?.danceName
            composer = kind
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.bold))
                .foregroundColor(Color.obsidian900)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.94))
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Label(toast, systemImage: "checkmark")
                .font(.footnote.weight(.bold))
                .foregroundColor(Color.obsidian900)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.gold400, in: Capsule())
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: toast) {
                    try? await Task.sleep(for: .seconds(1.6))
                    withAnimation(.easeOut(duration: 0.25)) { self.toast = nil }
                }
        }
    }

    // MARK: Actions
    private func save(text: String, voice: RecordedVoice?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || voice != nil else { return }
        let note = InstantNote(text: trimmed, audioPath: voice?.fileName, audioDuration: voice?.duration, danceName: composerDance)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            modelContext.insert(note)
            selectedDay = calendar.startOfDay(for: note.createdAt)
            composer = nil
        }
        try? modelContext.save()
        savedTick += 1
        showToast("Uložené")
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { toast = text }
    }

    private func togglePin(_ note: InstantNote) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { note.isPinned.toggle() }
        try? modelContext.save()
    }

    private func restore(_ note: InstantNote) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { note.importedAt = nil }
        try? modelContext.save()
    }

    private func delete(_ note: InstantNote) {
        if player.fileName == note.audioPath { player.stop() }
        MediaStorageManager.removeFile(named: note.audioPath)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { modelContext.delete(note) }
        try? modelContext.save()
    }

    /// Names of the figures notes were added to (a figure on a routine or in the library).
    private func loadFigureNames() {
        let ids = Set(notes.compactMap(\.linkedFigureId))
        guard !ids.isEmpty else { return }
        var names: [UUID: String] = [:]
        let nodes = (try? modelContext.fetch(FetchDescriptor<CanvasNode>(predicate: #Predicate { ids.contains($0.id) }))) ?? []
        for node in nodes { names[node.id] = node.figureName }
        let items = (try? modelContext.fetch(FetchDescriptor<FigureLibraryItem>(predicate: #Predicate { ids.contains($0.id) }))) ?? []
        for item in items { names[item.id] = item.name }
        figureNames = names
    }

    // MARK: Počúvať
    private func startListening() {
        let queue = voiceNotes
        guard !queue.isEmpty else { mode = .read; return }
        var index = 0
        func playNext() {
            guard index < queue.count, let file = queue[index].audioPath else {
                player.onFinish = nil
                player.stop()
                listeningId = nil
                mode = .read
                showToast("Prehraté všetky hlasovky")
                return
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { listeningId = queue[index].id }
            index += 1
            player.play(fileName: file)
        }
        player.onFinish = { playNext() }
        playNext()
    }

    private func stopListening() {
        guard player.onFinish != nil || listeningId != nil else { return }
        player.onFinish = nil
        player.stop()
        withAnimation { listeningId = nil }
    }
}

/// Blue for Standard, crimson for Latin, like the dance menu.
private func disciplineColor(_ dance: String) -> Color {
    DanceNames.rank(dance) < 5 ? Color.standardBlue : Color.latinCrimson
}

extension InstantNote {
    var hasText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    /// Short recordings sit inside the sentence; longer ones get their own row with speed and seeking.
    var hasInlineVoice: Bool { audioPath != nil && hasText && (audioDuration ?? 0) <= 20 }
}

// MARK: - One note
private struct JournalNoteCard: View {
    let note: InstantNote
    let figureName: String?
    let showsDate: Bool
    let isListening: Bool
    @ObservedObject var player: VoiceNotePlayer
    let onAddToFigure: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if note.hasInlineVoice, let file = note.audioPath {
                JournalFlowLayout(spacing: 4, lineSpacing: 6) {
                    ForEach(Array(note.text.split(separator: " ").enumerated()), id: \.offset) { _, word in
                        Text(String(word)).font(.body).foregroundColor(.white)
                    }
                    VoiceToken(fileName: file, duration: note.audioDuration ?? 0, player: player)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(note.text + ", hlasovka " + voiceTimeString(note.audioDuration ?? 0))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(named: "Prehrať hlasovku") { player.play(fileName: file) }
            } else {
                if note.hasText {
                    Text(note.text)
                        .font(.body)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let file = note.audioPath {
                    VoiceRow(fileName: file, duration: note.audioDuration ?? 0, player: player)
                }
            }
            if let media = note.videoPath ?? note.imagePath {
                HStack(spacing: 10) {
                    MediaThumbnailView(path: media, cornerRadius: 10)
                        .frame(width: 72, height: 54)
                    Text(note.videoPath != nil ? "Tréningové video" : "Fotka")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isListening ? Color.gold400.opacity(0.5) : .clear, lineWidth: 1)
        )
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.gold400.opacity(isListening ? 0.1 : 0))
        )
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(note.createdAt, format: showsDate ? .dateTime.day().month(.abbreviated).hour().minute() : .dateTime.hour().minute())
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundColor(.white.opacity(0.6))
            if let dance = note.danceName {
                HStack(spacing: 4) {
                    Circle().fill(disciplineColor(dance))
                        .frame(width: 6, height: 6)
                    Text(DanceNames.display(dance))
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            }
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(Color.gold300)
                    .accessibilityLabel("Pripnutá")
            }
            Spacer(minLength: 6)
            if let figureName {
                figureChip(figureName)
            } else if note.hasText && !note.isImported {
                Button(action: onAddToFigure) {
                    Label("K figúre", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color.gold400)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 28)
                        .overlay(Capsule().stroke(Color.gold400.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(.pressable(scale: 0.92))
                .accessibilityLabel("Pridať k figúre")
            }
        }
    }

    private func figureChip(_ name: String) -> some View {
        HStack(spacing: 5) {
            Rectangle().fill(Color.gold400).frame(width: 6, height: 6).rotationEffect(.degrees(45))
            Text(name).lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .frame(minHeight: 28)
        .background(Color.white.opacity(0.09), in: Capsule())
        .accessibilityLabel("Pridané k figúre \(name)")
    }
}

// MARK: - Voice in the text
/// A short voice note inside the sentence: play, its waveform filling up, the time left.
private struct VoiceToken: View {
    let fileName: String
    let duration: TimeInterval
    @ObservedObject var player: VoiceNotePlayer

    private var isMine: Bool { player.fileName == fileName }
    private var isPlaying: Bool { isMine && player.isPlaying }
    private var progress: Double { isMine && player.duration > 0 ? player.currentTime / player.duration : 0 }

    var body: some View {
        Button {
            if isPlaying { player.pause() } else { player.play(fileName: fileName) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(Color.obsidian900)
                    .frame(width: 20, height: 20)
                    .background(Color.gold400, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
                VoiceWaveform(fileName: fileName, progress: progress, bars: 10, maxHeight: 14)
                    .frame(width: 42)
                Text(voiceTimeString(isMine ? max(0, duration - player.currentTime) : duration))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundColor(Color.gold300)
            }
            .padding(.leading, 4)
            .padding(.trailing, 10)
            .frame(height: 30)
            .background(Color.gold500.opacity(isPlaying ? 0.32 : 0.18), in: Capsule())
            .scaleEffect(isPlaying ? 1.05 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)
        }
        .buttonStyle(.pressable(scale: 0.92))
    }
}

/// A longer voice note on its own row: play, seek on the waveform, speed.
private struct VoiceRow: View {
    let fileName: String
    let duration: TimeInterval
    @ObservedObject var player: VoiceNotePlayer

    private var isMine: Bool { player.fileName == fileName }
    private var isPlaying: Bool { isMine && player.isPlaying }
    private var progress: Double { isMine && player.duration > 0 ? player.currentTime / player.duration : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    if isPlaying { player.pause() } else { player.play(fileName: fileName) }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(Color.obsidian900)
                        .frame(width: 44, height: 44)
                        .background(Color.gold400, in: Circle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.pressable)
                .accessibilityLabel(isPlaying ? "Pozastaviť hlasovku" : "Prehrať hlasovku")

                GeometryReader { geo in
                    VoiceWaveform(fileName: fileName, progress: progress, bars: 32, maxHeight: 28)
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                            player.load(fileName: fileName)
                            player.seek(to: max(0, min(1, value.location.x / max(1, geo.size.width))) * player.duration)
                            if !player.isPlaying { player.toggle() }
                        })
                }
                .frame(height: 30)
                .accessibilityHidden(true)

                Text(voiceTimeString(isMine ? max(0, duration - player.currentTime) : duration))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.6))
            }
            if isMine {
                Button {
                    player.rate = player.rate >= 2 ? 1 : player.rate + 0.5
                } label: {
                    Text(player.rate.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "sk"))) + "×")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 30)
                        .background(Color.white.opacity(0.1), in: Capsule())
                        .contentTransition(.numericText())
                }
                .buttonStyle(.pressable(scale: 0.9))
                .accessibilityLabel("Rýchlosť prehrávania")
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isMine)
        .sensoryFeedback(.selection, trigger: player.rate)
    }
}

/// The loudness of a voice note as bars; the played part is gold.
private struct VoiceWaveform: View {
    let fileName: String
    let progress: Double
    let bars: Int
    let maxHeight: CGFloat

    @State private var levels: [CGFloat] = []

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<bars, id: \.self) { index in
                Capsule()
                    .fill(Color.gold400.opacity(Double(index) < progress * Double(bars) ? 1 : 0.35))
                    .frame(width: 2, height: max(3, (index < levels.count ? levels[index] : 0.3) * maxHeight))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.12), value: progress)
        .task(id: fileName) { levels = await VoiceWaveformLoader.levels(for: fileName, count: bars) }
    }
}

/// Reads how loud each part of a voice note is, once, off the main thread (a 10 minute note is read in
/// small chunks, never whole into memory).
enum VoiceWaveformLoader {
    private static var cache: [String: [CGFloat]] = [:]

    static func levels(for fileName: String, count: Int) async -> [CGFloat] {
        let key = "\(fileName)#\(count)"
        if let cached = cache[key] { return cached }
        guard MediaStorageManager.fileExists(fileName) else { return [] }
        let url = MediaStorageManager.url(for: fileName)
        let levels = await Task.detached(priority: .utility) { read(url, count: count) }.value
        cache[key] = levels
        return levels
    }

    nonisolated private static func read(_ url: URL, count: Int) -> [CGFloat] {
        guard count > 0, let file = try? AVAudioFile(forReading: url) else { return [] }
        let total = Int(file.length)
        let chunk: AVAudioFrameCount = 16_384
        guard total > 0, let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunk) else { return [] }
        let perBar = max(1, total / count)
        var sums = [Float](repeating: 0, count: count)
        var samples = [Int](repeating: 0, count: count)
        var position = 0
        while position < total {
            guard (try? file.read(into: buffer, frameCount: chunk)) != nil, buffer.frameLength > 0,
                  let data = buffer.floatChannelData?[0] else { break }
            let frames = Int(buffer.frameLength)
            var index = 0
            while index < frames {
                let bar = min(count - 1, (position + index) / perBar)
                sums[bar] += data[index] * data[index]
                samples[bar] += 1
                index += 8
            }
            position += frames
        }
        let rms = zip(sums, samples).map { CGFloat(($0 / Float(max(1, $1))).squareRoot()) }
        let peak = rms.max() ?? 0
        return rms.map { peak > 0 ? max(0.15, $0 / peak) : 0.15 }
    }
}

/// Words and inline views in lines, like text, so a voice note can sit right inside the sentence.
private struct JournalFlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = arrange(subviews, width: proposal.width ?? .infinity)
        let height = lines.reduce(0) { $0 + $1.height } + CGFloat(max(0, lines.count - 1)) * lineSpacing
        let width = lines.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for line in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for (index, size) in line.items {
                subviews[index].place(at: CGPoint(x: x, y: y + (line.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += line.height + lineSpacing
        }
    }

    private struct Line { var items: [(Int, CGSize)] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Line] {
        var lines = [Line()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !lines[lines.count - 1].items.isEmpty, lines[lines.count - 1].width + spacing + size.width > width {
                lines.append(Line())
            }
            var line = lines[lines.count - 1]
            line.width += (line.items.isEmpty ? 0 : spacing) + size.width
            line.height = max(line.height, size.height)
            line.items.append((index, size))
            lines[lines.count - 1] = line
        }
        return lines
    }
}

// MARK: - New note
struct RecordedVoice: Equatable {
    let fileName: String
    let duration: TimeInterval
}

/// The card that comes up for a new note: text with an optional voice note (or a voice note right away),
/// the dance, and save. The gold lines run down its edges when it opens (FieldEdgeSweep).
struct JournalComposer: View {
    enum Kind: Hashable { case text, voice }

    let kind: Kind
    @Binding var dance: String?
    let onSave: (String, RecordedVoice?) -> Void
    let onClose: () -> Void

    @StateObject private var recorder = VoiceNoteRecorder()
    @State private var text = ""
    @State private var voice: RecordedVoice?
    @State private var levels: [CGFloat] = []
    @State private var sweep = 0
    @FocusState private var isWriting: Bool

    private var isRecording: Bool { recorder.state == .recording }
    private var canSave: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || voice != nil || isRecording }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: isRecording ? "NAHRÁVAM" : "NOVÁ POZNÁMKA",
                              systemImage: isRecording ? "waveform" : "square.and.pencil", count: nil) {
                LiquidGlassCircleButton(icon: "xmark", label: "Zavrieť", size: 36) { close() }
            }
            TextField("", text: $text,
                      prompt: Text(kind == .voice ? "Dopíš k hlasovke (nepovinné)" : "Čo si chceš z tréningu zapamätať?")
                        .foregroundColor(.white.opacity(0.5)),
                      axis: .vertical)
                .lineLimit(2...6)
                .font(.body)
                .foregroundColor(.white)
                .focused($isWriting)
            if isRecording {
                recordingRow.transition(.scale(scale: 0.9).combined(with: .opacity))
            } else if let voice {
                recordedRow(voice).transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            if let error = recorder.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(Color.latinRed)
            }
            HStack(spacing: 10) {
                DanceMenuCapsule(selection: $dance)
                Spacer()
                LiquidGlassCircleButton(icon: isRecording ? "stop.fill" : "mic.fill",
                                        label: isRecording ? "Zastaviť nahrávanie" : "Nahrať hlasovku",
                                        isActive: isRecording, activeColor: Color.latinRed) { toggleRecording() }
                    .disabled(voice != nil && !isRecording)
            }
            PrimarySheetButton(title: voice != nil || isRecording ? "Uložiť s hlasovkou" : "Uložiť poznámku",
                               isLoading: false, isEnabled: canSave) { save() }
        }
        .padding(16)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
        .overlay { FieldEdgeSweep(trigger: sweep).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)) }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: recorder.state)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: voice)
        .sensoryFeedback(.impact(weight: .medium), trigger: isRecording)
        .onAppear {
            sweep += 1
            if kind == .voice { Task { await recorder.start() } } else { isWriting = true }
        }
        .onChange(of: recorder.level) { _, level in
            levels.append(level)
            if levels.count > 36 { levels.removeFirst(levels.count - 36) }
        }
        .onChange(of: recorder.state) { _, state in
            if state == .recorded, let result = recorder.takeResult() {
                voice = RecordedVoice(fileName: result.fileName, duration: result.duration)
            }
        }
        .onDisappear { if isRecording { recorder.discard() } }
    }

    private var recordingRow: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.latinRed)
                .frame(width: 10, height: 10)
                .phaseAnimator([1.0, 0.35]) { dot, phase in dot.opacity(phase) } animation: { _ in .easeInOut(duration: 0.6) }
            Text(voiceTimeString(recorder.elapsed))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(.white)
            HStack(spacing: 2) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    Capsule().fill(Color.latinRed).frame(width: 2, height: max(3, level * 30))
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .frame(height: 32)
            .clipped()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nahrávam, \(voiceTimeString(recorder.elapsed))")
    }

    private func recordedRow(_ voice: RecordedVoice) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .foregroundColor(Color.gold400)
            Text("Hlasovka \(voiceTimeString(voice.duration))")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color.gold300)
            Spacer()
            Button(role: .destructive) { removeVoice() } label: {
                Label("Zahodiť", systemImage: "trash")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.latinRed)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.pressable(scale: 0.92))
        }
        .padding(.horizontal, 12)
        .background(Color.gold500.opacity(0.14), in: Capsule())
    }

    private func toggleRecording() {
        if isRecording { recorder.stop() } else { Task { await recorder.start() } }
    }

    private func removeVoice() {
        MediaStorageManager.removeFile(named: voice?.fileName)
        voice = nil
    }

    private func save() {
        if isRecording { recorder.stop() }
        if recorder.state == .recorded, let result = recorder.takeResult() {
            voice = RecordedVoice(fileName: result.fileName, duration: result.duration)
        }
        onSave(text, voice)
    }

    private func close() {
        if isRecording { recorder.discard() }
        removeVoice()
        onClose()
    }
}
