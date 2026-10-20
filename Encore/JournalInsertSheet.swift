import SwiftData
import SwiftUI

// MARK: - From Denník into a figure's notes
/// Denník from inside a figure (BRAND_GUIDELINES §1A): the small notes, newest first. Text goes where the
/// cursor is, a voice note is dragged to its place in the text, a video becomes the figure's video or model.
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
                    .foregroundColor(.white.opacity(0.6))
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

// MARK: - Placing a voice note in the text
/// The voice note floats over the notes; drag it (or anywhere) and a gold line shows where it goes in the
/// text. "Vložiť sem" puts it there.
struct VoicePlacementOverlay: View {
    let ref: VoiceNoteRef
    let startPoint: CGPoint
    let controller: NoteEditorController
    let onCancel: () -> Void
    let onPlace: (Int) -> Void

    @State private var point: CGPoint?
    @State private var target: (index: Int, caret: CGRect)?

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            let current = point ?? startPoint
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.3)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                        .onChanged { value in move(to: value.location) })

                if let caret = target?.caret {
                    Capsule()
                        .fill(Color.gold400)
                        .frame(width: 3, height: caret.height + 8)
                        .position(x: caret.midX - origin.x, y: caret.midY - origin.y)
                        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: target?.index)
                }

                InlineVoiceToken(ref: ref, player: controller.player)
                    .scaleEffect(1.1)
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
                    .position(x: current.x - origin.x, y: current.y - origin.y - 36)
                    .allowsHitTesting(false)

                VStack(spacing: 12) {
                    Text("Potiahni hlasovku na miesto v texte")
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

    private func move(to location: CGPoint) {
        point = location
        // The note goes where the token's middle points, a little above the finger.
        target = controller.insertionPoint(nearGlobal: CGPoint(x: location.x - InlineVoiceToken.size.width / 2, y: location.y - 36))
    }
}
