import SwiftUI
import AVFoundation
import PhotosUI
import SwiftData
import OSLog

// MARK: - Strih lekcie (Nástroje, Plus)
/// A long video from a lesson or seminar cut into figures (BRAND_GUIDELINES §1A). Find the figure with the
/// slider and the second steps, mark its start and end, check it with "Prehrať úsek", name it and save.
/// Each clip goes to Fotky (album Encore) like every Encore video, and to the routine's videos when one is picked.
struct SeminarSplitterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Routine.name) private var routines: [Routine]

    // Source
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var sourceURL: URL?
    @State private var isLoadingVideo = false
    @State private var loadFailed = false
    @State private var player: AVPlayer?
    @State private var timeObserver: Any?
    @State private var boundaryObserver: Any?

    // Playback
    @State private var duration: Double = 0
    @State private var currentTime: Double = 0
    @State private var isPlaying = false

    // Marks
    @State private var clipStart: Double = 0
    @State private var clipEnd: Double = 30
    @State private var figureName = ""
    @State private var routine: Routine?

    // Saved
    @State private var savedClips: [SavedClip] = []
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var markTick = 0
    @State private var saveTick = 0

    private struct SavedClip: Identifiable {
        let id = UUID()
        let title: String
        let path: String
        let length: Double
    }

    private var clipLength: Double { clipEnd - clipStart }
    private var canSave: Bool { player != nil && clipLength >= 0.5 && !isSaving }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let player {
                            playerCard(player)
                            marksSection
                            if !savedClips.isEmpty { savedSection }
                        } else {
                            importCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: savedClips.count)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Strih lekcie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hotovo") { dismiss() }
                }
            }
            .alert("Figúru sa nepodarilo uložiť", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: "sk"))
        .sensoryFeedback(.impact(weight: .medium), trigger: markTick)
        .sensoryFeedback(.success, trigger: saveTick)
        .onChange(of: selectedPhotoItem) { _, item in load(item) }
        .onDisappear(perform: tearDown)
    }

    // MARK: Import
    private var importCard: some View {
        PhotosPicker(selection: $selectedPhotoItem, matching: .videos) {
            VStack(spacing: 12) {
                if isLoadingVideo {
                    ProgressView().tint(Color.gold400).controlSize(.large)
                    Text("Načítavam video…")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Dlhé video môže chvíľu trvať.")
                        .font(.footnote)
                        .foregroundColor(Color.textSecondary)
                } else {
                    Image(systemName: "film.stack.fill")
                        .font(.largeTitle)
                        .foregroundColor(Color.gold400)
                    Text("Vyber video z lekcie")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(loadFailed
                         ? "Video sa nepodarilo načítať. Skús iné alebo ho najprv stiahni do iPhonu."
                         : "Aj hodinovú nahrávku z lekcie alebo seminára rozdelíš na jednotlivé figúry.")
                        .font(.footnote)
                        .foregroundColor(loadFailed ? Color.latinRed : .white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 20)
            .homeCard(cornerRadius: 22)
        }
        .buttonStyle(.pressable(scale: 0.98))
        .disabled(isLoadingVideo)
    }

    // MARK: Player
    private func playerCard(_ player: AVPlayer) -> some View {
        VStack(spacing: 12) {
            ZStack {
                VideoTrimPlayerRepresentable(player: player)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Button(action: togglePlay) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 56, height: 56)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.pressable(scale: 0.88))
                .accessibilityLabel(isPlaying ? "Pozastaviť" : "Prehrať")
            }

            Slider(value: Binding(get: { currentTime }, set: { seek(to: $0) }), in: 0...max(duration, 0.1))
                .tint(Color.gold400)
                .accessibilityLabel("Čas vo videu")
                .accessibilityValue(Self.time(currentTime))

            HStack {
                Text(Self.time(currentTime, tenths: true))
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                Spacer()
                Text(Self.time(duration))
                    .font(.system(.footnote, design: .rounded).weight(.medium))
                    .monospacedDigit()
                    .foregroundColor(Color.textSecondary)
            }

            // Second steps: the slider finds the place, these find the exact moment.
            HStack(spacing: 8) {
                ForEach([-5.0, -1.0, 1.0, 5.0], id: \.self) { step in
                    Button {
                        seek(to: currentTime + step)
                    } label: {
                        Text(step < 0 ? "−\(Int(-step)) s" : "+\(Int(step)) s")
                            .font(.footnote.weight(.bold))
                            .monospacedDigit()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.pressable(scale: 0.92))
                    .accessibilityLabel(step < 0 ? "\(Int(-step)) sekúnd späť" : "\(Int(step)) sekúnd dopredu")
                }
            }
        }
        .padding(14)
        .homeCard(cornerRadius: 22)
    }

    // MARK: Marks
    private var marksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "FIGÚRA", systemImage: "scissors")
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    markButton("Začiatok", time: clipStart, color: Color.syncEmerald) {
                        clipStart = min(currentTime, max(duration - 0.5, 0))
                        if clipEnd <= clipStart + 0.5 { clipEnd = min(duration, clipStart + 30) }
                    }
                    markButton("Koniec", time: clipEnd, color: Color.latinRed) {
                        clipEnd = max(currentTime, clipStart + 0.5)
                    }
                }

                HStack {
                    Label("Dĺžka \(Self.time(max(clipLength, 0), tenths: true))", systemImage: "timer")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Button(action: playSelection) {
                        Label("Prehrať úsek", systemImage: "play.rectangle.fill")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(Color.gold400)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.pressable)
                    .disabled(clipLength < 0.5)
                }

                PlannerTextField(placeholder: "Názov figúry (napr. Natural Turn)", text: $figureName, systemImage: "textformat")

                if !routines.isEmpty {
                    Menu {
                        Button("Bez zostavy") { routine = nil }
                        ForEach(routines) { item in
                            Button("\(item.name) · \(DanceNames.display(item.danceName))") { routine = item }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .foregroundColor(Color.gold400)
                                .frame(width: 22)
                            Text(routine.map { "\($0.name) · \(DanceNames.display($0.danceName))" } ?? "Pridať k zostave (nepovinné)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(routine == nil ? .white.opacity(0.6) : .white)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Color.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                PrimarySheetButton(title: "Uložiť figúru", isLoading: isSaving, isEnabled: canSave, action: save)
            }
            .padding(14)
            .homeCard(cornerRadius: 22)
        }
    }

    private func markButton(_ title: String, time: Double, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
            markTick += 1
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 5) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(title.uppercased())
                        .font(.system(.caption2, design: .rounded).weight(.black))
                        .tracking(1)
                        .foregroundColor(color)
                }
                Text(Self.time(time, tenths: true))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .contentTransition(.numericText())
                Text("Ťukni = teraz")
                    .font(.caption2)
                    .foregroundColor(Color.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.pressable(scale: 0.95))
        .accessibilityLabel("\(title): \(Self.time(time))")
        .accessibilityHint("Nastaví sa na aktuálny čas vo videu")
    }

    // MARK: Saved
    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "ULOŽENÉ FIGÚRY", systemImage: "checkmark.seal.fill", count: savedClips.count)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(savedClips) { clip in
                    HStack(spacing: 12) {
                        MediaThumbnailView(path: clip.path, cornerRadius: 8)
                            .frame(width: 56, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(clip.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(Self.time(clip.length, tenths: true))
                                .font(.caption.weight(.medium))
                                .monospacedDigit()
                                .foregroundColor(Color.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color.syncEmerald)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    if clip.id != savedClips.last?.id { HomeRowDivider() }
                }
            }
            .homeCard(cornerRadius: 20)
            Text(PhotoLibraryVideoStore.hasAccess
                 ? "Figúry sú vo Fotkách v albume Encore a pri zostave v jej videách."
                 : "Figúry sú v Encore a pri zostave v jej videách. S prístupom k Fotkám by sa ukladali aj do Fotiek.")
                .font(.footnote)
                .foregroundColor(Color.textSecondary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: Loading
    private func load(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isLoadingVideo = true
        loadFailed = false
        Task {
            let movie = try? await item.loadTransferable(type: MovieTransferable.self)
            isLoadingVideo = false
            guard let movie else {
                loadFailed = true
                selectedPhotoItem = nil
                return
            }
            await start(with: movie.url)
        }
    }

    private func start(with url: URL) async {
        let asset = AVURLAsset(url: url)
        let seconds = (try? await asset.load(.duration)).map(CMTimeGetSeconds) ?? 0
        let newPlayer = AVPlayer(playerItem: AVPlayerItem(asset: asset))
        sourceURL = url
        duration = seconds.isFinite ? seconds : 0
        clipStart = 0
        clipEnd = min(duration, 30)
        timeObserver = newPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { time in
            MainActor.assumeIsolated {
                currentTime = CMTimeGetSeconds(time)
                isPlaying = newPlayer.timeControlStatus != .paused
            }
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { player = newPlayer }
    }

    // MARK: Playback
    private func togglePlay() {
        guard let player else { return }
        clearBoundary()
        if player.timeControlStatus == .paused { player.play() } else { player.pause() }
    }

    private func seek(to seconds: Double) {
        let clamped = min(max(seconds, 0), duration)
        currentTime = clamped
        player?.seek(to: CMTime(seconds: clamped, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Plays the marked part once and stops at its end.
    private func playSelection() {
        guard let player else { return }
        clearBoundary()
        seek(to: clipStart)
        let end = NSValue(time: CMTime(seconds: clipEnd, preferredTimescale: 600))
        boundaryObserver = player.addBoundaryTimeObserver(forTimes: [end], queue: .main) { [weak player] in
            player?.pause()
        }
        player.play()
    }

    private func clearBoundary() {
        if let boundaryObserver { player?.removeTimeObserver(boundaryObserver) }
        boundaryObserver = nil
    }

    private func tearDown() {
        player?.pause()
        clearBoundary()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
        // The imported copy of a long video can take gigabytes; it is only needed while this screen is open.
        if let sourceURL { try? FileManager.default.removeItem(at: sourceURL) }
    }

    // MARK: Saving
    private func save() {
        guard let sourceURL, canSave else { return }
        player?.pause()
        isSaving = true
        let start = clipStart, end = clipEnd
        let title = figureName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Figúra \(savedClips.count + 1)"
            : figureName.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = routine

        Task {
            defer { isSaving = false }
            do {
                let clipURL = try await Self.export(from: sourceURL, start: start, end: end)
                // Like every Encore video: into Fotky (album Encore); without access it stays in the app.
                let path: String
                if await PhotoLibraryVideoStore.requestAccess() {
                    path = try await PhotoLibraryVideoStore.save(videoAt: clipURL)
                } else {
                    path = try MediaStorageManager.moveIntoDocuments(from: clipURL, fileExtension: "mp4")
                }
                let entry = VideoMediaEntry(filePath: path, title: title, role: .coach)
                entry.routine = target
                modelContext.insert(entry)
                try? modelContext.save()

                savedClips.append(SavedClip(title: title, path: path, length: end - start))
                saveTick += 1
                // Ready for the next figure right after this one.
                clipStart = end
                clipEnd = min(duration, end + 30)
                figureName = ""
                seek(to: end)
            } catch {
                Logger.camera.error("Lesson clip save failed: \(error.localizedDescription, privacy: .public)")
                saveError = "Skús to znova. Ak to nepomôže, uvoľni miesto v iPhone."
            }
        }
    }

    /// The marked part as its own file, cut exactly (re-encoded at the highest quality).
    private static func export(from url: URL, start: Double, end: Double) async throws -> URL {
        let asset = AVURLAsset(url: url)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let output = FileManager.default.temporaryDirectory.appendingPathComponent("clip_\(UUID().uuidString).mp4")
        session.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            duration: CMTime(seconds: end - start, preferredTimescale: 600)
        )
        try await session.export(to: output, as: .mp4)
        return output
    }

    /// "12:05" or with tenths "12:05,3"; hours when the video is that long.
    static func time(_ seconds: Double, tenths: Bool = false) -> String {
        let total = max(seconds, 0)
        let whole = Int(total)
        let h = whole / 3600, m = (whole % 3600) / 60, s = whole % 60
        var text = h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
        if tenths { text += ",\(Int((total - Double(whole)) * 10))" }
        return text
    }
}

// MARK: - Xcode Canvas Preview
#Preview("SeminarSplitterView") {
    SeminarSplitterView()
        .previewWithSampleData()
}
