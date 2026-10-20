import SwiftUI
import AVKit
import Speech
import SwiftData
import Combine
import UniformTypeIdentifiers
import OSLog


// MARK: - Figure screen
/// Full-screen page of one figure: the video on top (portrait or landscape frame, Porovnanie next to it)
/// and the notes on a dark glass card below. While writing, the formatting bar replaces everything
/// else at the bottom, and the top and bottom edges blur the content scrolling under them.
struct FigureDetailCard: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var node: CanvasNode

    var realtimeManager: CanvasRealtimeManager? = nil
    /// Set when the screen is shown over another one; nil = presented modally and closed with dismiss.
    var onClose: (() -> Void)? = nil
    var onWritingChange: ((Bool) -> Void)? = nil
    @AppStorage("profileName") private var userName = "Tanečník"

    // Notes
    @State private var text = AttributedString()
    @State private var didLoadNotes = false
    @State private var saveTask: Task<Void, Never>? = nil
    @State private var sweepTrigger = 0
    @State private var isWriting = false
    @StateObject private var noteEditor = NoteEditorController()
    /// Voice notes the text had when the figure opened; one deleted from the text is removed on close.
    @State private var loadedVoiceFiles: Set<String> = []

    // Video
    @ObservedObject private var playback = FigureVideoPlayback.shared
    @State private var playerGeneration = 0
    @State private var videoUnavailable = false
    @State private var detectedPortrait: Bool? = nil
    @State private var videoHeightOverride: CGFloat? = nil
    @State private var dragStartHeight: CGFloat? = nil
    @State private var showCamera = false
    @State private var showMediaPicker = false
    @State private var showDuelComparison = false
    /// Duel: my video and the model's side by side instead of one video.
    @State private var isDuel = false
    @State private var showModelPicker = false
    @State private var showJournal = false
    /// A voice note from Denník being dragged to its place in the text.
    @State private var placingVoice: PendingVoice?
    @State private var notesFrame: CGRect = .zero

    private struct PendingVoice: Equatable {
        let ref: VoiceNoteRef
        let text: String?
        let noteId: UUID
    }
    @State private var showTimeline = false
    @State private var showPremiumPaywall = false
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var confirmDeleteVideo = false

    // Sharing with partner and coach
    @State private var shareStage: SharedVideoStore.Stage? = nil
    @State private var confirmShare = false
    @State private var confirmStopSharing = false
    @State private var confirmSaveToPhotos = false
    @State private var videoNotice: String? = nil
    @State private var videoError: String? = nil
    @State private var successCount = 0
    @State private var showEditFigure = false
    @State private var editName = ""
    @State private var editRhythm = ""

    private var rotation: Int { ((node.videoRotation ?? 0) % 360 + 360) % 360 }

    /// Portrait frame when the picture is upright-tall after the user's rotation.
    private var isPortraitLayout: Bool {
        let natural = detectedPortrait ?? false
        return rotation % 180 == 0 ? natural : !natural
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                EllegancePageBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        if isDuel {
                            FigureDuelSlots(
                                myPath: node.displayVideoPath,
                                modelPath: node.activeTargetVideoPath,
                                height: min((geo.size.width - 32) * 0.8, geo.size.height * 0.45),
                                onAddMine: { showMediaPicker = true },
                                onAddModel: { showModelPicker = true },
                                onCompare: { showDuelComparison = true }
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        } else {
                            videoSection(width: geo.size.width - 32, screenHeight: geo.size.height)
                                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        }
                        HomeSectionHeader(title: "POZNÁMKY", systemImage: "note.text")
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                        notesSheet
                        if AppFeatures.coachTools {
                            coachNotesCard
                            GuestNotesOnFigure(nodeId: node.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .frame(minHeight: geo.size.height - 60, alignment: .top)
                    // Empty space around the page: tap it to put the keyboard away.
                    .background {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { isWriting = false }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .overlay {
                if let pending = placingVoice {
                    VoicePlacementOverlay(
                        ref: pending.ref,
                        startPoint: CGPoint(x: notesFrame.midX, y: notesFrame.midY + 36),
                        controller: noteEditor,
                        onCancel: cancelVoicePlacement,
                        onPlace: { index in placeVoice(pending, at: index) }
                    )
                    .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: placingVoice)
            .safeAreaBar(edge: .top) { header }
            .safeAreaBar(edge: .bottom) {
                if isWriting {
                    NoteFormatBar(onFormat: { noteEditor.apply($0) }, isRecording: noteEditor.isRecording,
                                  onVoice: { noteEditor.toggleRecording() }) { isWriting = false }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: isWriting)
        }
        .preferredColorScheme(.dark)

        .onAppear {
            if !didLoadNotes {
                text = RichNote.attributed(for: node)
                loadedVoiceFiles = Set(RichNote.voiceNotes(in: text).map(\.fileName))
                didLoadNotes = true
            }
            setupPlayer(for: node.displayVideoPath)
        }
        .onDisappear {
            noteEditor.stopRecording()
            noteEditor.player.stop()
            persistNotes()
            removeDeletedVoiceNotes()
            playerGeneration += 1
            // With the sound on, the video plays on in the mini player above the tab bar.
            playback.cardDidClose(nodeId: node.id)
        }
        .onChange(of: text) { scheduleSave() }
        .onChange(of: node.notes) {
            // Changed from elsewhere (partner, coach, inbox): show it unless the user is typing.
            guard didLoadNotes, !isWriting else { return }
            let fresh = RichNote.attributed(for: node)
            if fresh != text { text = fresh }
        }
        .onChange(of: isWriting) { _, writing in
            if writing { sweepTrigger += 1 } else { noteEditor.stopRecording(); persistNotes() }
            onWritingChange?(writing)
        }
        .onChange(of: node.displayVideoPath) { _, newValue in
            videoHeightOverride = nil
            setupPlayer(for: newValue)
        }
        .onChange(of: showCamera) { _, isShowing in
            if isShowing { stopPlayer() } else { setupPlayer(for: node.displayVideoPath) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            DanceCameraView(ghostVideoPath: node.activeTargetVideoPath, savesToPhotos: true) { localPath in
                replaceVideo(with: localPath)
                showCamera = false
                routineDidChange()
                // A shared figure keeps being shared: partner and coach get the new take.
                if node.sharedVideoPath != nil { Task { await shareVideo() } }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showMediaPicker) {
            UniversalMediaPickerSheet(
                slotTitle: "Video figúry",
                currentPath: node.videoPath,
                onSelectMedia: { path in
                    replaceVideo(with: path)
                    routineDidChange()
                },
                onClearMedia: {}
            )
        }
        .sheet(isPresented: $showModelPicker) {
            UniversalMediaPickerSheet(
                slotTitle: "Vzor figúry",
                currentPath: node.activeTargetVideoPath,
                onSelectMedia: { path in
                    node.activeTargetVideoPath = path
                    routineDidChange()
                },
                onClearMedia: {}
            )
        }
        .sheet(isPresented: $showJournal) {
            JournalInsertSheet(onInsert: insertFromJournal, onUseVideo: useJournalVideo)
        }
        .onChange(of: isDuel) { _, duel in
            // One player at a time: the duel plays its own two.
            if duel { stopPlayer() } else { setupPlayer(for: node.displayVideoPath) }
        }
        .sheet(isPresented: $showDuelComparison) {
            DualVideoComparisonView(
                pathA: $node.videoPath,
                pathB: $node.activeTargetVideoPath,
                figureName: node.figureName,
                onSaveCorrection: addCorrection
            )
        }
        .confirmationDialog("Odstrániť video?", isPresented: $confirmDeleteVideo, titleVisibility: .visible) {
            Button("Odstrániť video", role: .destructive) { Task { await deleteVideo() } }
        } message: {
            Text(deleteVideoMessage)
        }
        .modifier(sharingDialogs)
        .alert("Figúra v tejto zostave", isPresented: $showEditFigure) {
            TextField("Názov figúry", text: $editName)
            TextField("Rytmus (napr. 1, 2, 3 alebo S, Q, Q)", text: $editRhythm)
            Button("Uložiť", action: saveFigureEdit)
            Button("Zrušiť", role: .cancel) {}
        } message: {
            Text("Zmena platí len v tejto zostave, knižnica figúr ostane bez zmeny.")
        }
    }

    private func saveFigureEdit() {
        let name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhythm = editRhythm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != node.figureName || rhythm != node.rhythm else { return }
        node.figureName = String(name.prefix(80))
        node.rhythm = String(rhythm.prefix(80))
        successCount += 1
        routineDidChange()
    }

    // MARK: - Sharing dialogs
    /// Kept apart from `body` so the compiler can type-check the long modifier chain.
    private var sharingDialogs: SharingDialogs { SharingDialogs(card: self) }

    fileprivate struct SharingDialogs: ViewModifier {
        let card: FigureDetailCard

        func body(content: Content) -> some View {
            card.applySharingDialogs(to: content)
        }
    }

    fileprivate func applySharingDialogs<V: View>(to content: V) -> some View {
        content
            .confirmationDialog("Zdieľať video s partnerom a trénerom?", isPresented: $confirmShare, titleVisibility: .visible) {
                Button("Zdieľať") { Task { await shareVideo() } }
            } message: {
                Text("Uvidia ho v tejto figúre ako zmenšenú kópiu (720p). Tvoj originál ostáva vo Fotkách. Zdieľané videá zaberajú miesto z tvojho plánu, preto zruš zdieľanie, keď video už netreba.")
            }
            .confirmationDialog("Zrušiť zdieľanie?", isPresented: $confirmStopSharing, titleVisibility: .visible) {
                Button("Zrušiť zdieľanie", role: .destructive) { Task { await stopSharing() } }
            } message: {
                Text("Kópia sa zmaže zo servera aj z Encore u partnera a trénera. Tvoj originál vo Fotkách ostane. Kto si video uložil do svojich Fotiek, tomu ostane.")
            }
            .confirmationDialog("Uložiť video do tvojich Fotiek?", isPresented: $confirmSaveToPhotos, titleVisibility: .visible) {
                Button("Uložiť do Fotiek") { Task { await saveSharedCopyToPhotos() } }
            } message: {
                Text("Uložíš si vlastnú kópiu do albumu Encore. Ostane ti, aj keď partner zdieľanie zruší, a pozrieš si ju aj bez internetu.")
            }
            .alert("Video", isPresented: Binding(get: { videoError != nil }, set: { if !$0 { videoError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(videoError ?? "")
            }
            .task(id: videoNotice) {
                guard videoNotice != nil else { return }
                try? await Task.sleep(for: .seconds(3))
                withAnimation(.easeOut(duration: 0.25)) { videoNotice = nil }
            }
            .sensoryFeedback(.success, trigger: successCount)
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 10) {
            Button {
                persistNotes()
                if let onClose { onClose() } else { dismiss() }
            } label: {
                Text("Zavrieť")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .glassEffect(.regular, in: .capsule)
            }
            .buttonStyle(.pressable)

            // Name and rhythm can differ in this routine (a shortened variation, other counts).
            Button {
                editName = node.figureName
                editRhythm = node.rhythm
                showEditFigure = true
            } label: {
                HStack(spacing: 5) {
                    Text(node.figureName)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "pencil")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(scale: 0.97))
            .accessibilityHint("Upraviť názov a rytmus figúry v tejto zostave")

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    LiquidGlassCircleButton(icon: "book.pages", label: "Denník") { showJournal = true }

                    LiquidGlassCircleButton(icon: "rectangle.split.2x1", label: isDuel ? "Jedno video" : "Duel: ja a vzor",
                                            isActive: isDuel) {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85)) { isDuel.toggle() }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Video
    @ViewBuilder
    private func videoSection(width: CGFloat, screenHeight: CGFloat) -> some View {
        let maxHeight = screenHeight * 0.72
        let defaultHeight = isPortraitLayout ? min(screenHeight * 0.55, width * 1.25) : width * 9 / 16
        let height = min(max(videoHeightOverride ?? defaultHeight, 150), maxHeight)

        VStack(spacing: 6) {
            ZStack {
                Color.black.opacity(0.88)

                if let path = node.displayVideoPath {
                    if MediaResolver.isImagePath(path: path), let image = MediaResolver.resolveImage(path: path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: rotation % 180 == 0 ? width : height, height: rotation % 180 == 0 ? height : width)
                            .rotationEffect(.degrees(Double(rotation)))
                    } else if playback.nodeId == node.id, let player = playback.player {
                        RotatableVideoView(player: player, rotation: rotation, size: CGSize(width: width, height: height))
                            .overlay(alignment: .bottomTrailing) { soundButton }
                    } else if videoUnavailable {
                        unavailableVideo(path: path)
                    } else {
                        ProgressView().tint(.white)
                    }
                } else {
                    emptyVideo
                }
            }
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if node.displayVideoPath != nil { videoMenu }
            }
            .overlay(alignment: .topLeading) { shareBadge }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: shareBadgeText)

            if node.displayVideoPath != nil {
                resizeHandle(currentHeight: height, maxHeight: maxHeight)
            }
            if node.videoPath != nil {
                timelineChip
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: isPortraitLayout)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: rotation)
    }

    /// The video starts muted so music in the hall keeps playing. With the sound on it keeps playing
    /// after the card closes (mini player, Lock Screen, Dynamic Island).
    private var soundButton: some View {
        Button(action: playback.toggleSound) {
            Image(systemName: playback.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(playback.isMuted ? Color.white : Color.gold400)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 40, height: 40)
                .glassEffect(.regular.interactive(), in: .circle)
                .frame(width: 48, height: 48)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.85))
        .padding(.trailing, 6)
        .padding(.bottom, 8)
        .sensoryFeedback(.selection, trigger: playback.isMuted)
        .accessibilityLabel(playback.isMuted ? "Zapnúť zvuk" : "Vypnúť zvuk")
    }

    /// The figure has a video, but it cannot be played here (deleted from Fotky, no access, offline).
    private func unavailableVideo(path: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "video.slash.fill")
                .font(.title2)
                .foregroundStyle(Color.gold400)
            Text(unavailableMessage(for: path))
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .accessibilityElement(children: .combine)
    }

    private func unavailableMessage(for path: String) -> String {
        if PhotoLibraryVideoStore.isReference(path) {
            return PhotoLibraryVideoStore.hasAccess
                ? "Video bolo zmazané z Fotiek. Pridaj ho znova."
                : "Povoľ Encore prístup k Fotkám v Nastaveniach iPhonu."
        }
        return node.videoPath == nil
            ? "Zdieľané video sa nepodarilo načítať. Skontroluj pripojenie."
            : "Video sa nenašlo. Pridaj ho znova."
    }

    private var emptyVideo: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.badge.plus")
                .font(.title)
                .foregroundStyle(Color.gold400)
            Text("Pridaj video figúry")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            HStack(spacing: 10) {
                Button { showCamera = true } label: {
                    Label("Natočiť", systemImage: "record.circle")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.obsidian900)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 40)
                        .background(Color.gold400, in: Capsule())
                }
                Button { showMediaPicker = true } label: {
                    Label("Z Fotiek", systemImage: "photo.on.rectangle")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 40)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
            }
            .buttonStyle(.pressable)
        }
    }

    private var videoMenu: some View {
        Menu {
            Button {
                node.videoRotation = (rotation + 90) % 360
                videoHeightOverride = nil
                try? node.modelContext?.save()
            } label: { Label("Otočiť video", systemImage: "rotate.right") }
            if node.videoPath != nil {
                Button { showCamera = true } label: { Label("Natočiť znova", systemImage: "arrow.triangle.2.circlepath") }
                if node.sharedVideoPath == nil {
                    if AppFeatures.sharedVideos {
                        Button { confirmShare = true } label: { Label("Zdieľať s partnerom a trénerom", systemImage: "person.2.fill") }
                    }
                } else {
                    Button { confirmStopSharing = true } label: { Label("Zrušiť zdieľanie", systemImage: "person.2.slash") }
                }
                Button(role: .destructive) { confirmDeleteVideo = true } label: { Label("Odstrániť video", systemImage: "trash") }
            } else if node.sharedVideoPath != nil {
                Button { confirmSaveToPhotos = true } label: { Label("Uložiť do mojich Fotiek", systemImage: "square.and.arrow.down") }
            }
        } label: {
            GlassCircleLabel(icon: "ellipsis", size: 36)
        }
        .disabled(shareStage != nil)
        .accessibilityLabel("Možnosti videa")
        .padding(10)
    }

    /// "Zdieľané", the progress of a running share, or a short confirmation.
    @ViewBuilder
    private var shareBadge: some View {
        if let text = shareBadgeText {
            HStack(spacing: 6) {
                if shareStage != nil {
                    ProgressView().controlSize(.mini).tint(.white)
                } else {
                    Image(systemName: node.videoPath == nil ? "person.2.fill" : "checkmark.circle.fill")
                        .foregroundStyle(Color.gold400)
                }
                Text(text)
                    .contentTransition(.opacity)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
            .padding(10)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        }
    }

    private var shareBadgeText: String? {
        switch shareStage {
        case .compressing: return "Pripravujem video…"
        case .uploading: return "Nahrávam…"
        case nil: break
        }
        if let videoNotice { return videoNotice }
        guard node.sharedVideoPath != nil else { return nil }
        return node.videoPath == nil ? "Zdieľané s tebou" : "Zdieľané"
    }

    private var deleteVideoMessage: String {
        var parts = [node.videoPath.map(PhotoLibraryVideoStore.isReference) == true
            ? "Video sa odstráni z figúry. Vo Fotkách ti ostane."
            : "Video sa zmaže z tejto figúry aj z telefónu."]
        if node.sharedVideoPath != nil { parts.append("Zruší sa aj zdieľanie s partnerom a trénerom.") }
        return parts.joined(separator: " ")
    }

    /// Drag to make the video taller or shorter; the notes follow.
    /// Every take of this figure by date (Premium).
    private var timelineChip: some View {
        let takes = node.timelineTakeCount
        let hasPremium = subscriptionManager.currentTier >= .premium
        return Button {
            if hasPremium { showTimeline = true } else { showPremiumPaywall = true }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: hasPremium ? "clock.arrow.circlepath" : "lock.fill")
                Text(takes > 1 ? "Časová os · \(slovakCount(takes, one: "záber", few: "zábery", many: "záberov"))" : "Časová os figúry")
                if !hasPremium {
                    Text("PREMIUM")
                        .font(.system(.caption2, design: .rounded).weight(.black))
                        .foregroundColor(Color.obsidian900)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gold400, in: Capsule())
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(Color.gold300)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Color.white.opacity(0.07), in: Capsule())
            .frame(minHeight: 44)
        }
        .buttonStyle(.pressable)
        .sheet(isPresented: $showTimeline) { FigureTimelineView(node: node, onSaveCorrection: addCorrection) }
        .sheet(isPresented: $showPremiumPaywall) { SubscriptionPaywallView(initialTier: .premium) }
    }

    /// A new video: the old take stays in the figure's timeline and the new one joins it.
    private func replaceVideo(with path: String) {
        if let old = node.videoPath, old != path { node.recordTake(old, in: modelContext) }
        node.videoPath = path
        node.recordTake(path, in: modelContext)
    }

    private func resizeHandle(currentHeight: CGFloat, maxHeight: CGFloat) -> some View {
        Capsule()
            .fill(Color.white.opacity(0.35))
            .frame(width: 44, height: 5)
            .frame(maxWidth: .infinity, minHeight: 22)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if dragStartHeight == nil { dragStartHeight = currentHeight }
                        videoHeightOverride = min(max((dragStartHeight ?? currentHeight) + value.translation.height, 150), maxHeight)
                    }
                    .onEnded { _ in dragStartHeight = nil }
            )
            .accessibilityLabel("Zmeniť výšku videa")
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = 40
                let base = videoHeightOverride ?? currentHeight
                videoHeightOverride = min(max(direction == .increment ? base + step : base - step, 150), maxHeight)
            }
    }

    // MARK: - Notes
    /// The notes like a notebook page: text with voice notes right where they were recorded.
    private var notesSheet: some View {
        ZStack(alignment: .topLeading) {
            FigureNotesEditor(text: $text, isEditing: $isWriting, controller: noteEditor)

            if text.characters.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hlavné slovo")
                        .font(.system(size: 22, weight: .bold))
                    Text("Tu si píš poznámky k figúre…")
                        .font(.system(size: NoteStyle.defaultSize))
                }
                .foregroundStyle(Color.white.opacity(0.5))
                .padding(.horizontal, 5)
                .padding(.vertical, 8)
                .allowsHitTesting(false)
            }

        }
        .overlay(alignment: .bottomLeading) {
            if let error = noteEditor.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(Color.latinRed)
                    .padding(.horizontal, 5)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .padding(.horizontal, 4)
        .overlay { FieldEdgeSweep(trigger: sweepTrigger) }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { notesFrame = $0 }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture { isWriting = true }
    }

    /// Remark from the coach: read-only here, written from the coach's own screen.
    @ViewBuilder
    private var coachNotesCard: some View {
        if let remark = node.coachNotes, !remark.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                    Text("Od trénera")
                    Spacer(minLength: 8)
                    if let author = node.coachNotesAuthor, !author.isEmpty {
                        Text(author).lineLimit(1)
                    }
                    if let date = node.coachNotesAt {
                        Text(date.formatted(.dateTime.day().month(.abbreviated)))
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.gold400)

                Text(remark)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Saving
    private func scheduleSave() {
        guard didLoadNotes else { return }
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            persistNotes()
        }
    }

    // MARK: - From Denník
    /// Text goes where the cursor is; a voice note (the figure's own copy) is dragged to its place first.
    private func insertFromJournal(_ note: InstantNote) {
        if let audio = note.audioPath {
            let source = MediaStorageManager.url(for: audio)
            let name = "voice_\(UUID().uuidString).m4a"
            let target = MediaStorageManager.url(for: name)
            let pending = PendingVoice(ref: VoiceNoteRef(fileName: name, duration: note.audioDuration ?? 0),
                                       text: note.hasText ? note.text : nil, noteId: note.id)
            Task {
                let copied = await Task.detached(priority: .userInitiated) {
                    (try? FileManager.default.copyItem(at: source, to: target)) != nil
                }.value
                guard copied else { return }
                // After the sheet has gone, so the notes are visible.
                try? await Task.sleep(for: .milliseconds(350))
                placingVoice = pending
            }
        } else {
            noteEditor.insertText(note.text.trimmingCharacters(in: .whitespacesAndNewlines))
            markInFigure(note.id)
        }
    }

    private func placeVoice(_ pending: PendingVoice, at index: Int) {
        noteEditor.insertVoice(pending.ref, followedBy: pending.text, at: index)
        markInFigure(pending.noteId)
        placingVoice = nil
        successCount += 1
    }

    /// The copy was made for this figure; not placed, it goes again.
    private func cancelVoicePlacement() {
        if let pending = placingVoice { MediaStorageManager.removeFile(named: pending.ref.fileName) }
        placingVoice = nil
    }

    /// A video from Denník becomes my video or the model (then the duel shows both).
    private func useJournalVideo(_ note: InstantNote, asModel: Bool) {
        guard let video = note.videoPath else { return }
        if asModel {
            node.activeTargetVideoPath = video
            if !isDuel { withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { isDuel = true } }
        } else {
            replaceVideo(with: video)
        }
        routineDidChange()
        markInFigure(note.id)
    }

    /// Denník shows the note as already in a figure.
    private func markInFigure(_ noteId: UUID) {
        let descriptor = FetchDescriptor<InstantNote>(predicate: #Predicate { $0.id == noteId })
        guard let note = try? modelContext.fetch(descriptor).first else { return }
        note.importedAt = Date()
        note.linkedFigureId = node.id
        note.linkedRoutineId = node.routine?.id
        try? modelContext.save()
    }

    /// Recordings deleted from the text leave the phone when the figure closes (undo works until then).
    private func removeDeletedVoiceNotes() {
        let kept = Set(RichNote.voiceNotes(in: text).map(\.fileName))
        for file in loadedVoiceFiles.union(noteEditor.recordedFiles).subtracting(kept) {
            MediaStorageManager.removeFile(named: file)
        }
    }

    /// Saves the notes if they really changed. Opening the screen never saves anything.
    /// Formatting changes stay on this phone; only a change of the plain text is synced.
    private func persistNotes() {
        saveTask?.cancel()
        saveTask = nil
        guard didLoadNotes else { return }
        guard RichNote.attributed(for: node) != text else { return }

        let plain = RichNote.plain(text)
        let plainChanged = plain != node.notes
        let hasFormatting = text != AttributedString(plain)
        node.notes = plain
        node.notesRichData = hasFormatting ? RichNote.encode(text) : nil
        try? modelContext.save()

        guard plainChanged else { return }
        realtimeManager?.broadcastNodeUpdated(node: node, senderName: userName)
        if let routine = node.routine {
            routine.updatedAt = Date()
            routine.lastModifiedBy = userName
            try? routine.modelContext?.save()
            SupabaseSyncManager.shared.syncRoutineOnBackground(routine)
        }
    }

    /// A shared copy is withdrawn first; if that fails nothing is deleted, so the user can retry.
    private func deleteVideo() async {
        guard let videoPath = node.videoPath else { return }
        if let shared = node.sharedVideoPath {
            do {
                try await SharedVideoStore.stopSharing(shared)
            } catch {
                videoError = error.localizedDescription
                return
            }
            node.replaceSharedVideoPath(nil)
        }
        stopPlayer()
        MediaStorageManager.removeFile(named: videoPath)   // a Fotky video stays in Fotky
        // A file kept in Encore is gone now, so its take leaves the timeline too; a Fotky take stays.
        if !PhotoLibraryVideoStore.isReference(videoPath) {
            node.mediaVault.filter { $0.filePath == videoPath }.forEach(modelContext.delete)
        }
        node.videoPath = nil
        routineDidChange()
    }

    // MARK: - Sharing
    private func shareVideo() async {
        guard let original = node.videoPath, shareStage == nil else { return }
        withAnimation { shareStage = .compressing }
        defer { withAnimation { shareStage = nil } }

        // The server checks that the figure is in your routine, so a brand new figure goes up first.
        if let routine = node.routine { await SupabaseSyncManager.shared.syncRoutineNow(routine) }
        do {
            let result = try await SharedVideoStore.share(originalPath: original, nodeId: node.id) { stage in
                withAnimation { shareStage = stage }
            }
            node.replaceSharedVideoPath(result.videoPath)
            routineDidChange()
            videoNotice = "Zdieľané · \(result.usage.text)"
            successCount += 1
        } catch {
            videoError = error.localizedDescription
        }
    }

    private func stopSharing() async {
        guard let shared = node.sharedVideoPath else { return }
        do {
            try await SharedVideoStore.stopSharing(shared)
            node.replaceSharedVideoPath(nil)
            routineDidChange()
            videoNotice = "Zdieľanie zrušené"
            successCount += 1
        } catch {
            videoError = error.localizedDescription
        }
    }

    /// The viewer keeps an own copy in Fotky; the shared copy itself stays as it is.
    private func saveSharedCopyToPhotos() async {
        guard let shared = node.sharedVideoPath else { return }
        guard await PhotoLibraryVideoStore.requestAccess() else {
            videoError = "Povoľ Encore prístup k Fotkám v Nastaveniach iPhonu."
            return
        }
        guard let cached = await SharedVideoStore.localURL(for: shared) else {
            videoError = "Video sa nepodarilo stiahnuť. Skontroluj pripojenie."
            return
        }
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        do {
            try FileManager.default.copyItem(at: cached, to: copy)
            _ = try await PhotoLibraryVideoStore.save(videoAt: copy)
            videoNotice = "Uložené do Fotiek"
            successCount += 1
        } catch {
            try? FileManager.default.removeItem(at: copy)
            videoError = "Video sa nepodarilo uložiť do Fotiek."
        }
    }

    /// Saves, syncs the routine and updates the partner's open canvas.
    /// A correction from the comparison becomes one more line in the notes, synced like any edit.
    private func addCorrection(_ correction: FigureCorrection) {
        persistNotes()   // keep anything typed but not saved yet
        let updated = RichNote.appending(correction.noteLine, to: node)
        node.notes = updated.plain
        node.notesRichData = updated.rich
        routineDidChange()
    }

    private func routineDidChange() {
        try? node.modelContext?.save()
        if let routine = node.routine {
            routine.updatedAt = Date()
            routine.lastModifiedBy = userName
            try? routine.modelContext?.save()
            SupabaseSyncManager.shared.syncRoutineOnBackground(routine)
        }
        realtimeManager?.broadcastNodeUpdated(node: node, senderName: userName)
    }

    // MARK: - Player
    /// Reopening the figure whose video plays in the mini player takes it back into the card, sound and position kept.
    private func setupPlayer(for path: String?) {
        playerGeneration += 1
        videoUnavailable = false
        playback.cardDidOpen(nodeId: node.id)
        guard let path, !MediaResolver.isImagePath(path: path) else {
            stopPlayer()
            return
        }

        // A video in Fotky is looked up asynchronously. Only the newest request may start a player:
        // closing the card or opening the camera meanwhile bumps the generation.
        let generation = playerGeneration
        Task { @MainActor in
            let url = await MediaResolver.videoURL(path: path)
            guard generation == playerGeneration else { return }
            if let url { startPlayer(url) } else { videoUnavailable = true }
        }
    }

    private func startPlayer(_ url: URL) {
        playback.show(url: url, nodeId: node.id, title: node.figureName, subtitle: node.routine?.name ?? "Encore")
        Task { @MainActor in
            detectedPortrait = await Self.isPortrait(url)
        }
    }

    private func stopPlayer() {
        playerGeneration += 1
        playback.stop(nodeId: node.id)
    }

    /// True when the video was recorded upright (taller than wide, after rotation).
    private static func isPortrait(_ url: URL) async -> Bool? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let size = try? await track.load(.naturalSize),
              let transform = try? await track.load(.preferredTransform) else { return nil }
        let rotated = size.applying(transform)
        return abs(rotated.height) > abs(rotated.width)
    }
}

// MARK: - Looping Player view helpers
class LoopingPlayerUIView: UIView {
    private let playerLayer = AVPlayerLayer()
    private var playerLooper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?
    private var rate: Float
    private var isPaused = false

    init(url: URL, rate: Float) {
        self.rate = rate
        super.init(frame: .zero)

        let playerItem = AVPlayerItem(asset: AVURLAsset(url: url))
        let player = AVQueuePlayer(playerItem: playerItem)
        player.actionAtItemEnd = .none
        self.queuePlayer = player

        playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)

        // Audio session through the coordinator, so it never collides with the camera.
        Task { [weak self] in
            try? await AudioSessionCoordinator.shared.activate(.player)
            guard let self, !self.isPaused else { return }
            player.play()
            player.rate = self.rate
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }

    func setRate(_ newRate: Float) {
        rate = newRate
        if !isPaused { queuePlayer?.rate = newRate }
    }

    func setPaused(_ paused: Bool) {
        guard paused != isPaused else { return }
        isPaused = paused
        if paused {
            queuePlayer?.pause()
        } else {
            queuePlayer?.play()
            queuePlayer?.rate = rate
        }
    }

    func stop() {
        queuePlayer?.pause()
        playerLooper?.disableLooping()
        playerLooper = nil
        queuePlayer = nil
        Task {
            await AudioSessionCoordinator.shared.deactivate(.player)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// A clip that plays in a loop. Tap the video (or the small button) to pause and resume.
/// Looping preview for any stored video path (app file, Supabase or Fotky). It looks the video up itself,
/// so callers never have to know where the video lives.
struct LoopingVideoPlayer: View {
    let videoPath: String
    let rate: Float

    private enum Source: Equatable { case loading, ready(URL), missing }

    @State private var source: Source = .loading

    var body: some View {
        ZStack {
            switch source {
            case .loading:
                Color.obsidian800
                ProgressView().tint(Color.gold400)
            case .ready(let url):
                LoopingPlayback(videoURL: url, rate: rate)
                    .transition(.opacity)
            case .missing:
                Color.obsidian800
                VStack(spacing: 6) {
                    Image(systemName: "video.slash.fill")
                        .font(.title3)
                        .foregroundColor(Color.gold400)
                    Text(missingMessage)
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(12)
            }
        }
        .animation(.easeOut(duration: 0.2), value: source)
        .task(id: videoPath) {
            source = .loading
            source = await MediaResolver.videoURL(path: videoPath).map(Source.ready) ?? .missing
        }
    }

    private var missingMessage: String {
        guard PhotoLibraryVideoStore.isReference(videoPath) else { return "Video sa nenašlo." }
        return PhotoLibraryVideoStore.hasAccess
            ? "Video bolo zmazané z Fotiek."
            : "Povoľ Encore prístup k Fotkám v Nastaveniach iPhonu."
    }
}

private struct LoopingPlayback: View {
    let videoURL: URL
    let rate: Float

    @State private var isPaused = false

    var body: some View {
        LoopingPlayerLayerView(videoURL: videoURL, rate: rate, isPaused: isPaused)
            .contentShape(Rectangle())
            .onTapGesture { isPaused.toggle() }
            .overlay {
                if isPaused {
                    Image(systemName: "play.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .glassEffect(.regular, in: .circle)
                        .allowsHitTesting(false)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .overlay(alignment: .bottomLeading) {
                LiquidGlassCircleButton(
                    icon: isPaused ? "play.fill" : "pause.fill",
                    label: isPaused ? "Prehrať video" : "Pozastaviť video",
                    size: 36
                ) { isPaused.toggle() }
                .padding(10)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isPaused)
            .sensoryFeedback(.selection, trigger: isPaused)
    }
}

private struct LoopingPlayerLayerView: UIViewRepresentable {
    let videoURL: URL
    let rate: Float
    let isPaused: Bool

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(url: videoURL, rate: rate)
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        uiView.setRate(rate)
        uiView.setPaused(isPaused)
    }

    static func dismantleUIView(_ uiView: LoopingPlayerUIView, context: Context) {
        uiView.stop()
    }
}

// MARK: - Speech Recognition Manager
@MainActor
class SpeechRecognizerHelper: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var audioLevel: CGFloat = 0.0
    /// Slovak message when dictation cannot start (permission denied, no recogniser, engine failure).
    @Published var errorMessage: String?
    
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?
    
    init() {
        if let slovak = SFSpeechRecognizer(locale: Locale(identifier: "sk-SK")) {
            self.recognizer = slovak
        } else {
            self.recognizer = SFSpeechRecognizer() // Fallback to system locale
        }
    }
    
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        Task {
            if #available(iOS 17.0, *) {
                _ = await AVAudioApplication.requestRecordPermission()
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { _ in }
            }
        }
    }
    
    func startTranscribing() {
        errorMessage = nil
        Task {
            guard await ensurePermissions() else { return }
            beginTranscribing()
        }
    }

    /// Asks for both permissions the first time and explains clearly when one was refused.
    private func ensurePermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            errorMessage = "Povoľ rozpoznávanie reči v Nastaveniach iPhonu (Encore → Rozpoznávanie reči)."
            return false
        }
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            errorMessage = "Povoľ mikrofón v Nastaveniach iPhonu (Encore → Mikrofón)."
            return false
        }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Rozpoznávanie reči teraz nie je dostupné. Skontroluj pripojenie na internet."
            return false
        }
        return true
    }

    private func beginTranscribing() {
        guard let recognizer = recognizer, recognizer.isAvailable else { return }

        // ✅ Audio session cez koordinátora — aktivujeme .speech PRED štartom audioEngine.
        // Koordinátor nastaví .record/.measurement a bezpečne odovzdá session od .player.
        Task {
            do {
                try await AudioSessionCoordinator.shared.activate(.speech)
            } catch {
                Logger.audio.error("Speech audio session activation failed: \(error.localizedDescription, privacy: .public)")
                return
            }

            audioEngine = AVAudioEngine()
            request = SFSpeechAudioBufferRecognitionRequest()

            guard let audioEngine = audioEngine, let request = request else { return }
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
            request.addsPunctuation = true
            request.contextualStrings = [
                "Waltz", "Valčík", "Tango", "Slowfox", "Quickstep", "Samba", "Cha-Cha", "Čača", "Rumba", "Paso Doble", "Jive",
                "Chassé", "Rondé", "Fleckerl", "Contra Check", "Whisk", "Feather Step", "Hover Corte", "Telemark", "Impetus",
                "Natural Spin Turn", "Reverse Pivot", "Botafogo", "Volta", "Samba Rolls", "New York", "Spot Turn", "Alemana",
                "Rumba Walks", "Sliding Doors", "Opening Out", "Promenade", "Appell", "Huit", "Chasse Cape", "Link", "Whip",
                "Fallaway", "Toe Heel", "MPM", "BPM", "Sway", "Rise & Fall", "CBMP", "CBM", "Pohyb", "Držanie", "Rám", "Nášľap",
                "Chodidlo", "Rotácia", "Panva", "Partnerka", "Partner", "Tréner", "Rytmus", "Akcent", "Zdvih", "Klesanie"
            ]

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                request.append(buffer)
                
                // Native Apple AVFoundation Audio Metering (RMS / Decibel Calculation)
                guard let channelData = buffer.floatChannelData?[0] else { return }
                let frames = Int(buffer.frameLength)
                guard frames > 0 else { return }
                
                var sum: Float = 0
                for i in 0..<frames {
                    let sample = channelData[i]
                    sum += sample * sample
                }
                let rms = sqrt(sum / Float(frames))
                let avgPower = 20 * log10(max(rms, 0.0001))
                let normalized = CGFloat(max(0.0, min(1.0, (avgPower + 45) / 45)))
                
                Task { @MainActor in
                    self?.audioLevel = normalized
                }
            }

            audioEngine.prepare()
            do {
                try audioEngine.start()
            } catch {
                errorMessage = "Mikrofón sa nepodarilo spustiť. Skús to znova."
                inputNode.removeTap(onBus: 0)
                self.audioEngine = nil
                self.request = nil
                await AudioSessionCoordinator.shared.deactivate(.speech)
                return
            }

            isRecording = true
            transcript = ""
            audioLevel = 0.0

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }

                let text = result?.bestTranscription.formattedString ?? ""
                let isDone = error != nil || result?.isFinal == true

                DispatchQueue.main.async {
                    // A cancelled task reports an empty result: never wipe what was already heard.
                    if !text.isEmpty { self.transcript = text }
                    if isDone {
                        self.stopTranscribing()
                    }
                }
            }
        }
    }
    
    /// Stops transcribing and returns the best transcript captured so far.
    /// We capture transcript BEFORE cancelling the task to avoid race condition
    /// where async main-queue callback would arrive after task is nil.
    @discardableResult
    func stopTranscribing() -> String {
        let capturedTranscript = transcript
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()

        audioEngine = nil
        request = nil
        task = nil
        isRecording = false
        audioLevel = 0.0

        Task {
            await AudioSessionCoordinator.shared.deactivate(.speech)
        }

        return capturedTranscript
    }
}

// MARK: - Native Video Camera Recorder (Apple Standard)
struct VideoRecorderView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onRecordComplete: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.mediaTypes = [UTType.movie.identifier]
            picker.cameraCaptureMode = .video
            picker.videoQuality = .typeHigh
            picker.cameraDevice = .rear
            picker.allowsEditing = false
            if UIImagePickerController.isFlashAvailable(for: .rear) {
                picker.cameraFlashMode = .off
            }
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: VideoRecorderView

        init(_ parent: VideoRecorderView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                do {
                    let filename = try MediaStorageManager.moveIntoDocuments(from: videoURL, fileExtension: "mp4")
                    parent.onRecordComplete(filename)
                } catch {
                    Logger.camera.error("Moving recorded video failed: \(error.localizedDescription, privacy: .public)")
                    parent.dismiss()
                }
            } else {
                parent.dismiss()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
/// Notes captured on Home that are not in any figure yet; one tap copies the text or uses the video.
/// Deleting notes belongs to the Notes screen, not here.
struct InstantNotesInboxSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(filter: #Predicate<InstantNote> { $0.importedAt == nil },
           sort: \InstantNote.createdAt, order: .reverse) private var instantNotes: [InstantNote]

    let onImportText: (String) -> Void
    let onImportVideo: (String) -> Void

    @State private var isExpanded = false
    @State private var importCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .foregroundColor(Color.gold400)
                    Text("Vložiť z Poznámok")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text("\(instantNotes.count)")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundColor(Color.obsidian900)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.gold400, in: Capsule())
                        .contentTransition(.numericText())
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(14)
                .homeCard(cornerRadius: 16)
            }
            .buttonStyle(.pressable)
            .accessibilityHint(isExpanded ? "Skryť poznámky" : "Ukázať poznámky z Domova")

            if isExpanded {
                if instantNotes.isEmpty {
                    Text("Všetky poznámky z Domova sú už pri figúrach.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.65))
                        .padding(.horizontal, 4)
                        .transition(.opacity)
                } else {
                    ForEach(instantNotes) { note in
                        noteCard(note)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: importCount)
    }

    private func noteCard(_ note: InstantNote) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(note.createdAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

            if !note.text.isEmpty {
                Text(note.text)
                    .font(.callout)
                    .foregroundColor(.white)
                    .lineLimit(4)
            }
            if note.videoPath != nil {
                Label("Video", systemImage: "video.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Color.gold400)
            }

            HStack(spacing: 8) {
                if !note.text.isEmpty {
                    chip("Vložiť text", icon: "text.quote") {
                        onImportText(note.text)
                        markImported(note)
                    }
                }
                if let videoPath = note.videoPath {
                    chip("Použiť video", icon: "video.badge.plus") {
                        onImportVideo(videoPath)
                        markImported(note)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 16)
    }

    private func chip(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.bold))
                .foregroundColor(Color.obsidian900)
                .padding(.horizontal, 12)
                .frame(minHeight: 34)
                .background(Color.gold400, in: Capsule())
        }
        .buttonStyle(.pressable)
    }

    /// The note stays (it can be found under Poznámky); it only leaves this list.
    private func markImported(_ note: InstantNote) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)) {
            note.importedAt = Date()
        }
        try? modelContext.save()
        importCount += 1
    }
}
