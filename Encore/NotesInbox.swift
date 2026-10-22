import SwiftUI
import SwiftData

extension InstantNote {
    var kindIcon: String {
        if audioPath != nil { return "waveform" }
        if videoPath != nil { return "video.fill" }
        if imagePath != nil { return "photo.fill" }
        return "text.alignleft"
    }

    var previewText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if audioPath != nil { return "Hlasová poznámka · \(voiceTimeString(audioDuration ?? 0))" }
        return videoPath != nil ? "Tréningové video" : "Prázdna poznámka"
    }
}

// MARK: - Home strip
/// Not-yet-imported notes under the capture field on Home. One note fills the row; more notes scroll
/// and snap to the same left edge as the rest of the screen.
struct NotesInboxStrip: View {
    let notes: [InstantNote]
    let onOpenAll: () -> Void
    let onOpenNote: (InstantNote) -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "DENNÍK", systemImage: "book.pages", count: notes.count) {
                Button(action: onOpenAll) {
                    HStack(spacing: 4) {
                        Text("Všetky")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.white.opacity(0.7))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Celý denník")
            }

            if notes.isEmpty {
                Text("Čo zapíšeš alebo nahráš, uloží sa do Denníka. Neskôr to jedným ťuknutím pridáš k figúre.")
                    .font(.caption)
                    .foregroundColor(Color.white.opacity(0.78))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else if notes.count == 1, let note = notes.first {
                card(note, isFullWidth: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(notes.prefix(12)) { note in
                            card(note, isFullWidth: false)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.7, anchor: .leading).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, 2)
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: notes.map(\.id))
        .sensoryFeedback(.selection, trigger: notes.first?.isPinned)
    }

    private func card(_ note: InstantNote, isFullWidth: Bool) -> some View {
        Button { onOpenNote(note) } label: { NoteCard(note: note, isFullWidth: isFullWidth) }
            .buttonStyle(.pressable)
            .contextMenu {
                Button {
                    note.isPinned.toggle()
                    try? modelContext.save()
                } label: {
                    Label(note.isPinned ? "Odopnúť" : "Pripnúť", systemImage: note.isPinned ? "pin.slash" : "pin")
                }
                Button(role: .destructive) {
                    MediaStorageManager.removeFile(named: note.audioPath)
                    modelContext.delete(note)
                    try? modelContext.save()
                } label: {
                    Label("Zmazať", systemImage: "trash")
                }
            }
    }
}

private struct NoteCard: View {
    let note: InstantNote
    var isFullWidth = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: note.kindIcon)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(Color.gold400)
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(Color.gold300)
                        .accessibilityLabel("Pripnutá")
                }
                Spacer(minLength: 0)
                Text(note.createdAt, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
                    .font(.caption2.weight(.medium))
                    .foregroundColor(Color.textSecondary)
            }

            Text(note.previewText)
                .font(.footnote.weight(.medium))
                .foregroundColor(.white.opacity(0.92))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            if let dance = note.danceName {
                Text(dance)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(Color.obsidian900)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gold400, in: Capsule())
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(width: isFullWidth ? nil : 186, height: 118, alignment: .topLeading)
        .frame(maxWidth: isFullWidth ? .infinity : nil, alignment: .topLeading)
        .homeCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Edit one note
/// One note, laid out like Home: recording or video on top, the text field, then what to do with it.
struct NoteDetailSheet: View {
    @Bindable var note: InstantNote
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showFigurePicker = false
    @State private var confirmDelete = false
    @State private var sweepTrigger = 0
    @FocusState private var isWriting: Bool

    private var hasText: Bool { !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        meta

                        if let audioPath = note.audioPath {
                            section("NAHRÁVKA", systemImage: "waveform") {
                                VStack(alignment: .leading, spacing: 10) {
                                    VoiceNotePlayerView(fileName: audioPath)
                                    Text("Vypočuj si nahrávku a nižšie napíš, čo z nej chceš ponechať.")
                                        .font(.caption)
                                        .foregroundColor(Color.white.opacity(0.65))
                                }
                                .padding(14)
                                .homeCard()
                            }
                        }

                        if let videoPath = note.videoPath {
                            section("VIDEO", systemImage: "video.fill") {
                                VStack(alignment: .leading, spacing: 10) {
                                    LoopingVideoPlayer(videoPath: videoPath, rate: 1.0)
                                        .frame(height: 220)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    Text("K figúre ho pripojíš v jej detaile.")
                                        .font(.caption)
                                        .foregroundColor(Color.white.opacity(0.65))
                                }
                            }
                        }

                        section("TEXT", systemImage: "text.alignleft") { editor }

                        actions
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Poznámka")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hotovo") {
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showFigurePicker) {
                FigurePickerSheet(note: note) { dismiss() }
            }
            .confirmationDialog("Zmazať poznámku?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Zmazať", role: .destructive) {
                    MediaStorageManager.removeFile(named: note.audioPath)
                    modelContext.delete(note)
                    try? modelContext.save()
                    dismiss()
                }
            }
            .onChange(of: isWriting) { _, writing in
                if writing { sweepTrigger += 1 }
            }
            .environment(\.locale, Locale(identifier: "sk"))
        }
        .preferredColorScheme(.dark)
    }

    private var meta: some View {
        HStack(spacing: 10) {
            Image(systemName: note.kindIcon)
                .font(.footnote.weight(.bold))
                .foregroundColor(Color.gold400)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.08), in: Circle())
                .accessibilityHidden(true)
            Text(note.createdAt, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
                .font(.footnote.weight(.medium))
                .foregroundColor(Color.white.opacity(0.75))
            Spacer(minLength: 8)
            DanceMenuCapsule(selection: $note.danceName)
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if note.text.isEmpty {
                Text(note.audioPath != nil ? "Napíš, čo si z nahrávky chceš zapamätať…" : "Napíš poznámku…")
                    .font(.callout)
                    .foregroundColor(Color.textPlaceholder)
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            TextEditor(text: $note.text)
                .focused($isWriting)
                .scrollContentBackground(.hidden)
                .font(.callout.weight(.medium))
                .foregroundColor(.white)
                .frame(minHeight: 160)
                .accessibilityLabel("Text poznámky")
        }
        .padding(12)
        .homeCard()
        .overlay { FieldEdgeSweep(trigger: sweepTrigger).padding(12) }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if note.isImported {
                Label("Pridané k figúre", systemImage: "checkmark.seal.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.syncEmerald)
                    .frame(maxWidth: .infinity)
            }

            PrimarySheetButton(
                title: note.isImported ? "Pridať k ďalšej figúre" : "Pridať k figúre",
                isLoading: false,
                isEnabled: hasText
            ) {
                showFigurePicker = true
            }

            if !hasText {
                Text("Najprv napíš text, ktorý chceš k figúre pridať.")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                    .transition(.opacity)
            }

            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Zmazať poznámku", systemImage: "trash")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.latinRed)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.pressable)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: hasText)
    }

    private func section<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: title, systemImage: systemImage)
            content()
        }
    }
}

// MARK: - Add a note to a figure
/// Adds the note to a figure on a routine canvas: its text, voice note and video, each on its own line at the
/// end, as they are inside a figure (no date or label). Library figures hold only text, so they are offered
/// only for notes with text. The note stays in Denník and is only marked as imported, so it can be restored.
struct FigurePickerSheet: View {
    let note: InstantNote
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CanvasNode.figureName) private var nodes: [CanvasNode]
    @Query(sort: \FigureLibraryItem.name) private var library: [FigureLibraryItem]
    @State private var search = ""

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    private var matchingNodes: [CanvasNode] {
        nodes.filter { node in
            guard let routine = node.routine else { return false }
            if let dance = note.danceName, routine.danceName != dance { return false }
            return query.isEmpty || node.figureName.lowercased().contains(query) || routine.name.lowercased().contains(query)
        }
    }

    private var matchingLibrary: [FigureLibraryItem] {
        library.filter { item in
            if let dance = note.danceName, item.danceName != dance { return false }
            return query.isEmpty || item.name.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if !matchingNodes.isEmpty {
                            HomeSectionHeader(title: "Z MOJICH ZOSTÁV", systemImage: "square.grid.2x2.fill")
                            ForEach(matchingNodes) { node in
                                figureRow(title: node.figureName, subtitle: node.routine?.name ?? "") { add(to: node) }
                            }
                        }
                        if note.hasText, !matchingLibrary.isEmpty {
                            HomeSectionHeader(title: "KNIŽNICA FIGÚR", systemImage: "books.vertical.fill")
                                .padding(.top, matchingNodes.isEmpty ? 0 : 12)
                            ForEach(matchingLibrary) { item in
                                figureRow(title: item.name, subtitle: item.danceName) { add(to: item) }
                            }
                        }
                        if matchingNodes.isEmpty && (!note.hasText || matchingLibrary.isEmpty) {
                            ContentUnavailableView.search(text: search)
                                .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }
            .searchable(text: $search, prompt: "Hľadať figúru alebo zostavu")
            .navigationTitle("Vybrať figúru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zrušiť") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func figureRow(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(Color.white.opacity(0.65))
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(Color.gold400)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .homeCard()
        }
        .buttonStyle(.pressable(scale: 0.97))
        .accessibilityHint("Pridá poznámku k tejto figúre")
    }

    private var trimmedText: String { note.text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func finish() {
        note.importedAt = Date()
        try? modelContext.save()
        HapticFeedback.medium()
        dismiss()
        onDone()
    }

    private func add(to node: CanvasNode) {
        Task {
            var pieces: [AttributedString] = []
            if note.hasText { pieces.append(AttributedString(trimmedText)) }
            // The figure's own copy, so deleting the note in Denník keeps the recording in the figure.
            if let audio = note.audioPath, let copy = await MediaStorageManager.copyVoiceNote(audio) {
                pieces.append(NoteMedia.voice(VoiceNoteRef(fileName: copy, duration: note.audioDuration ?? 0)).piece)
            }
            if let video = note.videoPath {
                let portrait = await VideoStill.isPortrait(await MediaResolver.videoURL(path: video)) ?? false
                pieces.append(NoteMedia.video(VideoNoteRef(path: video, isPortrait: portrait)).piece)
            }
            guard !pieces.isEmpty else { return }
            let updated = RichNote.appending(pieces, to: node)
            node.notes = updated.plain
            node.notesRichData = updated.rich
            note.linkedFigureId = node.id
            note.linkedRoutineId = node.routine?.id
            if let routine = node.routine {
                routine.updatedAt = Date()
                SupabaseSyncManager.shared.syncRoutineOnBackground(routine)
            }
            finish()
        }
    }

    private func add(to item: FigureLibraryItem) {
        item.techniqueNotes = item.techniqueNotes.isEmpty ? trimmedText : item.techniqueNotes + "\n" + trimmedText
        note.linkedFigureId = item.id
        finish()
    }
}
