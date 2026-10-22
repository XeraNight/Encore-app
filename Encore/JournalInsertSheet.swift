import SwiftData
import SwiftUI

// MARK: - From Denník into a figure's notes
/// What of a Denník note goes into a figure's notes: each kind on its own, never glued together.
enum JournalPart { case text, voice, video }

/// Denník from inside a figure (BRAND_GUIDELINES §1A): the small notes, newest first. Its text, voice note and
/// video each have their own button and are dragged to their place in the notes; a video can also become the
/// figure's video or model.
struct JournalInsertSheet: View {
    let onInsert: (InstantNote, JournalPart) -> Void
    let onUseVideo: (InstantNote, _ asModel: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \InstantNote.createdAt, order: .reverse) private var notes: [InstantNote]
    @StateObject private var player = VoiceNotePlayer()
    @State private var showJournal = false

    private var calendar: Calendar { PlannerCalendar.calendar }

    private var days: [(day: Date, notes: [InstantNote])] {
        let grouped = Dictionary(grouping: notes) { calendar.startOfDay(for: $0.createdAt) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                if notes.isEmpty {
                    Text("Denník je zatiaľ prázdny. Rýchle poznámky z Domova sa zobrazia tu a odtiaľ ich vložíš do figúry.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(24)
                        .homeCard(cornerRadius: 20)
                        .padding(.horizontal, 20)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(days, id: \.day) { group in
                                HomeSectionHeader(title: group.day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)).uppercased(),
                                                  systemImage: "calendar")
                                ForEach(group.notes) { row($0) }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("Z denníka")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zavrieť") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Celý denník") { showJournal = true } }
            }
            .sheet(isPresented: $showJournal) { TrainingJournalView() }
            .environment(\.locale, Locale(identifier: "sk"))
            .onDisappear { player.stop() }
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ note: InstantNote) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(note.createdAt, format: .dateTime.hour().minute())
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundColor(Color.textSecondary)
                if let dance = note.danceName {
                    Text(DanceNames.display(dance))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer(minLength: 6)
                if note.isImported {
                    Label("V figúre", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.syncEmerald)
                }
            }
            if note.hasText {
                Text(note.text)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let audio = note.audioPath {
                InlineVoiceToken(ref: VoiceNoteRef(fileName: audio, duration: note.audioDuration ?? 0), player: player)
            }
            if let video = note.videoPath {
                MediaThumbnailView(path: video, cornerRadius: 12)
                    .frame(height: 120)
            }
            actions(for: note)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 18)
    }

    /// One button per kind the note has; side by side when they fit.
    private func actions(for note: InstantNote) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { actionButtons(for: note) }
            VStack(alignment: .leading, spacing: 8) { actionButtons(for: note) }
        }
    }

    @ViewBuilder
    private func actionButtons(for note: InstantNote) -> some View {
        if note.hasText {
            Button { insert(note, .text) } label: { actionLabel("Vložiť text", icon: "text.quote") }
                .buttonStyle(.pressable(scale: 0.96))
        }
        if note.audioPath != nil {
            Button { insert(note, .voice) } label: { actionLabel("Vložiť hlasovku", icon: "waveform") }
                .buttonStyle(.pressable(scale: 0.96))
        }
        if note.videoPath != nil {
            Menu {
                Button { insert(note, .video) } label: { Label("Vložiť do poznámok", systemImage: "text.insert") }
                Button { use(note, asModel: false) } label: { Label("Ako moje video", systemImage: "person.fill") }
                Button { use(note, asModel: true) } label: { Label("Ako vzor", systemImage: "star.fill") }
            } label: {
                actionLabel("Video", icon: "video.fill")
            }
        }
    }

    private func insert(_ note: InstantNote, _ part: JournalPart) {
        dismiss()
        onInsert(note, part)
    }

    private func use(_ note: InstantNote, asModel: Bool) {
        dismiss()
        onUseVideo(note, asModel)
    }

    private func actionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.footnote.weight(.bold))
            .foregroundColor(Color.obsidian900)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(Color.gold400, in: Capsule())
    }
}

// MARK: - Placing a piece in the notes
/// A piece of Denník on its way into a figure's notes.
enum PlacedPiece: Equatable {
    case text(String)
    case voice(VoiceNoteRef)
    case video(VideoNoteRef)

    var hint: String {
        switch self {
        case .text: return "Potiahni text na miesto v poznámkach"
        case .voice: return "Potiahni hlasovku na miesto v texte"
        case .video: return "Potiahni video medzi odseky"
        }
    }
}

/// The piece floats over the notes. Drag it and a gold mark shows where it goes: a cursor in the text, or a line
/// between paragraphs for a video. Only the piece takes touches, so a finger still scrolls the notes under it,
/// and dragging the piece to the top or bottom edge scrolls on its own: any place in long notes can be reached.
struct PlacementOverlay: View {
    let piece: PlacedPiece
    let controller: NoteEditorController
    /// The notes on screen (window coordinates); it moves while the page scrolls.
    let notesFrame: CGRect
    @Binding var target: Int?

    /// Middle of the floating piece (window coordinates).
    @State private var center: CGPoint?
    @State private var dragStart: CGPoint?
    @State private var mark: CGRect?
    @State private var visible: CGRect = .zero
    @State private var previewWidth: CGFloat = 0
    /// Points per frame the page scrolls while the piece is held near an edge.
    @State private var edgeSpeed: CGFloat = 0

    private static let edgeZone: CGFloat = 80

    private var isBlock: Bool {
        if case .video = piece { return true }
        return false
    }

    var body: some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .global)
            ZStack(alignment: .topLeading) {
                if let mark {
                    Capsule()
                        .fill(Color.gold400)
                        .frame(width: isBlock ? mark.width : 3, height: isBlock ? 3 : mark.height + 8)
                        .shadow(color: Color.gold400.opacity(0.6), radius: 6)
                        .position(x: mark.midX - frame.minX, y: mark.midY - frame.minY)
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: target)
                        .allowsHitTesting(false)
                }
                if let center {
                    preview
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { previewWidth = $0 }
                        .scaleEffect(dragStart == nil ? 1 : 1.08)
                        .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
                        .contentShape(Rectangle())
                        .gesture(drag)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: dragStart == nil)
                        .position(x: center.x - frame.minX, y: center.y - frame.minY)
                }
            }
            .onAppear {
                visible = frame
                start(in: frame)
            }
            .onChange(of: frame) { _, newFrame in visible = newFrame }
        }
        // The page scrolled under the piece: the spot under it changed.
        .onChange(of: notesFrame) { retarget() }
        .task(id: edgeSpeed) {
            guard edgeSpeed != 0 else { return }
            while !Task.isCancelled {
                controller.scrollPage(by: edgeSpeed)
                retarget()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
        .sensoryFeedback(.selection, trigger: target)
    }

    @ViewBuilder
    private var preview: some View {
        switch piece {
        case .text(let text):
            Label(text, systemImage: "text.quote")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(maxWidth: 220, minHeight: 36)
                .fixedSize()
                .background(Color.obsidian900.opacity(0.92), in: Capsule())
                .overlay(Capsule().stroke(Color.gold400.opacity(0.6), lineWidth: 1))
        case .voice(let ref):
            InlineVoiceToken(ref: ref, player: controller.player)
        case .video(let ref):
            MediaThumbnailView(path: ref.path, cornerRadius: 12, showsFormatBadge: false)
                .frame(width: ref.isPortrait ? 63 : 144, height: ref.isPortrait ? 112 : 81)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.gold400.opacity(0.6), lineWidth: 1))
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                if dragStart == nil { dragStart = center }
                guard let dragStart else { return }
                let y = min(max(dragStart.y + value.translation.height, visible.minY + 24), visible.maxY - 24)
                let x = min(max(dragStart.x + value.translation.width, visible.minX + 24), visible.maxX - 24)
                center = CGPoint(x: x, y: y)
                retarget()
                edgeSpeed = speed(at: y)
            }
            .onEnded { _ in
                dragStart = nil
                edgeSpeed = 0
            }
    }

    /// Starts at the top of the notes when they are on screen, otherwise in the middle of what is visible.
    private func start(in frame: CGRect) {
        let y = min(max(notesFrame.minY + 60, frame.minY + Self.edgeZone), frame.maxY - Self.edgeZone)
        center = CGPoint(x: frame.midX, y: y)
        retarget()
    }

    /// Faster the deeper into the edge zone, up and down.
    private func speed(at y: CGFloat) -> CGFloat {
        if y < visible.minY + Self.edgeZone { return -14 * (1 - (y - visible.minY) / Self.edgeZone) }
        if y > visible.maxY - Self.edgeZone { return 14 * (1 - (visible.maxY - y) / Self.edgeZone) }
        return 0
    }

    /// Text and voice go where the piece starts, a video to the paragraph edge nearest its middle.
    private func retarget() {
        guard let center else { return }
        if isBlock {
            let point = controller.blockInsertionPoint(nearGlobal: center)
            target = point?.index
            mark = point?.line
        } else {
            let point = controller.insertionPoint(nearGlobal: CGPoint(x: center.x - previewWidth / 2, y: center.y))
            target = point?.index
            mark = point?.caret
        }
    }
}

/// Under the notes while a piece is placed: what to do, "Zrušiť" and "Vložiť sem".
struct PlacementBar: View {
    let hint: String
    let canPlace: Bool
    let onCancel: () -> Void
    let onPlace: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                Text(hint)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text("Poznámkami posúvaš prstom, pri okraji sa posunú samé.")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
            .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Zrušiť")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.pressable)
                PrimarySheetButton(title: "Vložiť sem", isLoading: false, isEnabled: canPlace, action: onPlace)
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }
}
