import SwiftData
import SwiftUI

// MARK: - From Denník into a figure's notes
/// Denník from inside a figure (BRAND_GUIDELINES §1A): the small notes, newest first. Text goes where the
/// cursor is, a voice note or a video is dragged to its place in the text; a video can also become the
/// figure's video or model.
struct JournalInsertSheet: View {
    let onInsert: (InstantNote) -> Void
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

    @ViewBuilder
    private func actions(for note: InstantNote) -> some View {
        if note.videoPath != nil {
            Menu {
                Button {
                    dismiss()
                    onInsert(note)
                } label: { Label("Vložiť do poznámok", systemImage: "text.insert") }
                Button { use(note, asModel: false) } label: { Label("Ako moje video", systemImage: "person.fill") }
                Button { use(note, asModel: true) } label: { Label("Ako vzor", systemImage: "star.fill") }
            } label: {
                actionLabel("Použiť video vo figúre", icon: "video.fill")
            }
        } else if note.hasText || note.audioPath != nil {
            Button {
                dismiss()
                onInsert(note)
            } label: {
                actionLabel(note.audioPath != nil ? "Vložiť hlasovku do poznámok" : "Vložiť do poznámok", icon: "text.insert")
            }
            .buttonStyle(.pressable(scale: 0.96))
        }
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

// MARK: - Placing a voice note or a video in the text
/// The voice note or video floats over the notes; drag it (or anywhere) and a gold line shows where it goes:
/// a cursor in the text for a voice note, a line between paragraphs for a video. "Vložiť sem" puts it there.
struct MediaPlacementOverlay: View {
    let media: NoteMedia
    let startPoint: CGPoint
    let controller: NoteEditorController
    let onCancel: () -> Void
    let onPlace: (Int) -> Void

    @State private var point: CGPoint?
    @State private var target: (index: Int, mark: CGRect)?

    private var isVideo: Bool {
        if case .video = media { return true }
        return false
    }

    private var previewSize: CGSize {
        switch media {
        case .voice: return InlineVoiceToken.size
        case .video(let ref): return ref.isPortrait ? CGSize(width: 63, height: 112) : CGSize(width: 144, height: 81)
        }
    }

    /// The preview floats this far above the finger, so the finger never hides the spot.
    private var lift: CGFloat { previewSize.height / 2 + 20 }

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            let current = point ?? startPoint
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.3)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { value in move(to: value.location) })

                if let mark = target?.mark {
                    Capsule()
                        .fill(Color.gold400)
                        .frame(width: isVideo ? mark.width : 3, height: isVideo ? 3 : mark.height + 8)
                        .shadow(color: Color.gold400.opacity(0.6), radius: 6)
                        .position(x: mark.midX - origin.x, y: mark.midY - origin.y)
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: target?.index)
                }

                preview
                    .scaleEffect(1.1)
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
                    .position(x: current.x - origin.x, y: current.y - origin.y - lift)
                    .allowsHitTesting(false)

                VStack(spacing: 12) {
                    Text(isVideo ? "Potiahni video medzi odseky" : "Potiahni hlasovku na miesto v texte")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5), in: Capsule())
                    Spacer()
                    HStack(spacing: 12) {
                        Button(action: onCancel) {
                            Text("Zrušiť")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.pressable)
                        PrimarySheetButton(title: "Vložiť sem", isLoading: false, isEnabled: target != nil) {
                            if let index = target?.index { onPlace(index) }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .ignoresSafeArea(.keyboard)
        .sensoryFeedback(.selection, trigger: target?.index)
        .onAppear { move(to: startPoint) }
    }

    @ViewBuilder
    private var preview: some View {
        switch media {
        case .voice(let ref):
            InlineVoiceToken(ref: ref, player: controller.player)
        case .video(let ref):
            MediaThumbnailView(path: ref.path, cornerRadius: 12)
                .frame(width: previewSize.width, height: previewSize.height)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.gold400.opacity(0.6), lineWidth: 1))
        }
    }

    private func move(to location: CGPoint) {
        point = location
        // A voice note goes where the token starts, a video to the paragraph edge nearest its middle.
        switch media {
        case .voice:
            target = controller.insertionPoint(nearGlobal: CGPoint(x: location.x - previewSize.width / 2, y: location.y - lift))
                .map { ($0.index, $0.caret) }
        case .video:
            target = controller.blockInsertionPoint(nearGlobal: CGPoint(x: location.x, y: location.y - lift))
                .map { ($0.index, $0.line) }
        }
    }
}
