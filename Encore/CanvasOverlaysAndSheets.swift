import SwiftUI
import SwiftData
import UIKit

// MARK: - Figures Drawer Sheet
/// Adds a library figure of this dance to the canvas; a missing one can be created right here.
struct FiguresDrawerSheet: View {
    @Binding var isPresented: Bool
    let danceName: String
    let libraryItems: [FigureLibraryItem]
    var onSelectFigure: (FigureLibraryItem) -> Void

    @State private var query = ""
    @State private var showNewFigure = false
    @State private var addCount = 0

    private var filtered: [FigureLibraryItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let items = needle.isEmpty ? libraryItems : libraryItems.filter { $0.name.localizedStandardContains(needle) }
        return items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        searchField
                            .padding(.bottom, 6)

                        HomeSectionHeader(title: DanceNames.display(danceName).uppercased(), count: filtered.count)
                            .padding(.horizontal, 4)

                        if filtered.isEmpty {
                            Text(libraryItems.isEmpty ? "V knižnici zatiaľ nie je žiadna figúra tohto tanca." : "Žiadna figúra s týmto názvom.")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.65))
                                .padding(.horizontal, 4)
                        }

                        ForEach(filtered) { item in
                            Button {
                                addCount += 1
                                onSelectFigure(item)
                            } label: { row(item) }
                            .buttonStyle(.pressable(scale: 0.97))
                        }

                        Button { showNewFigure = true } label: {
                            Label(query.isEmpty ? "Nová figúra" : "Nová figúra „\(query)“", systemImage: "plus")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Color.gold400)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Color.gold400.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                                )
                        }
                        .buttonStyle(.pressable)
                        .padding(.top, 6)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Pridať figúru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušiť") { isPresented = false }
                        .foregroundColor(.gold400)
                }
            }
            .sheet(isPresented: $showNewFigure) {
                NewFigureSheet(fixedDance: danceName) { figure in
                    onSelectFigure(figure)
                }
            }
            .sensoryFeedback(.success, trigger: addCount)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            TextField("", text: $query, prompt: Text("Hľadať figúru").foregroundColor(.white.opacity(0.5)))
                .foregroundColor(.white)
                .autocorrectionDisabled()
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func row(_ item: FigureLibraryItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                if !item.rhythm.isEmpty {
                    Text(item.rhythm)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundColor(Color.gold400)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Pridať na plátno")
    }
}

// MARK: - Transition Edit Sheet
/// A note on the step between two figures, saved as you type.
struct TransitionEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let fromNode: CanvasNode
    let toNode: CanvasNode
    let realtimeManager: CanvasRealtimeManager?
    var onSave: () -> Void

    @AppStorage("profileName") private var userName = "Tanečník"
    @State private var notesText = ""
    @State private var autoSaveTask: Task<Void, Never>? = nil
    @State private var isAutoSaved = false
    @State private var sweepTrigger = 0
    @FocusState private var isWriting: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 10) {
                            figurePill(fromNode.figureName)
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Color.gold400)
                            figurePill(toNode.figureName)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HomeSectionHeader(title: "PRECHOD", systemImage: "arrow.triangle.turn.up.right.diamond") {
                                if isAutoSaved {
                                    Label("Uložené", systemImage: "checkmark.circle.fill")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(Color.syncEmerald)
                                        .transition(.opacity.combined(with: .scale))
                                }
                            }
                            ZStack(alignment: .topLeading) {
                                if notesText.isEmpty {
                                    Text("Ako sa dostaneš z jednej figúry do druhej…")
                                        .font(.callout)
                                        .foregroundColor(.white.opacity(0.5))
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $notesText)
                                    .focused($isWriting)
                                    .scrollContentBackground(.hidden)
                                    .font(.callout)
                                    .foregroundColor(.white)
                                    .tint(Color.gold400)
                            }
                            .frame(minHeight: 160)
                            .padding(10)
                            .homeCard(cornerRadius: 18)
                            .overlay { FieldEdgeSweep(trigger: sweepTrigger) }
                        }
                    }
                    .padding(20)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isAutoSaved)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Prechod")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hotovo") {
                        saveNow()
                        onSave()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.gold400)
                }
            }
            .onAppear { notesText = toNode.transitionNotes }
            .onChange(of: isWriting) { _, writing in if writing { sweepTrigger += 1 } }
            .onChange(of: notesText) { scheduleSave() }
            .onDisappear { saveNow() }
            .sensoryFeedback(.success, trigger: isAutoSaved) { _, saved in saved }
        }
    }

    private func figurePill(_ name: String) -> some View {
        Text(name)
            .font(.footnote.weight(.bold))
            .foregroundColor(.white)
            .lineLimit(2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .homeCard(cornerRadius: 12)
    }

    private func scheduleSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, saveNow() else { return }
            isAutoSaved = true
            try? await Task.sleep(for: .seconds(2))
            isAutoSaved = false
        }
    }

    /// Saves and shares the note if it changed; true when something was saved.
    @discardableResult
    private func saveNow() -> Bool {
        guard toNode.transitionNotes != notesText else { return false }
        toNode.transitionNotes = notesText
        try? modelContext.save()
        realtimeManager?.broadcastTransitionUpdated(node: toNode, senderName: userName)

        if let routine = toNode.routine {
            routine.updatedAt = Date()
            routine.lastModifiedBy = userName
            try? routine.modelContext?.save()
            SupabaseSyncManager.shared.syncRoutineOnBackground(routine)
        }
        return true
    }
}

// MARK: - UIKit Canvas Gesture View
struct CanvasGestureView: UIViewRepresentable {
    var onPanChanged: (CGSize) -> Void
    var onPanEnded: (CGSize) -> Void
    var onPinchChanged: (CGFloat) -> Void
    var onPinchEnded: (CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.minimumNumberOfTouches = 1
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pinch)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onPanChanged = onPanChanged
        context.coordinator.onPanEnded = onPanEnded
        context.coordinator.onPinchChanged = onPinchChanged
        context.coordinator.onPinchEnded = onPinchEnded
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPanChanged: onPanChanged,
            onPanEnded: onPanEnded,
            onPinchChanged: onPinchChanged,
            onPinchEnded: onPinchEnded
        )
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPanChanged: (CGSize) -> Void
        var onPanEnded: (CGSize) -> Void
        var onPinchChanged: (CGFloat) -> Void
        var onPinchEnded: (CGFloat) -> Void

        init(
            onPanChanged: @escaping (CGSize) -> Void,
            onPanEnded: @escaping (CGSize) -> Void,
            onPinchChanged: @escaping (CGFloat) -> Void,
            onPinchEnded: @escaping (CGFloat) -> Void
        ) {
            self.onPanChanged = onPanChanged
            self.onPanEnded = onPanEnded
            self.onPinchChanged = onPinchChanged
            self.onPinchEnded = onPinchEnded
        }

        @objc func handlePan(_ gr: UIPanGestureRecognizer) {
            guard gr.numberOfTouches <= 1 else { return }
            let t = gr.translation(in: gr.view)
            let delta = CGSize(width: t.x, height: t.y)
            switch gr.state {
            case .changed:           onPanChanged(delta)
            case .ended, .cancelled: onPanEnded(delta)
            default: break
            }
        }

        @objc func handlePinch(_ gr: UIPinchGestureRecognizer) {
            switch gr.state {
            case .changed:           onPinchChanged(gr.scale)
            case .ended, .cancelled: onPinchEnded(gr.scale)
            default: break
            }
        }

        func gestureRecognizer(_ gr: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            if (gr is UIPanGestureRecognizer && other is UIPinchGestureRecognizer) ||
               (gr is UIPinchGestureRecognizer && other is UIPanGestureRecognizer) {
                return false
            }
            return true
        }
        func gestureRecognizer(_ gr: UIGestureRecognizer, shouldRequireFailureOf other: UIGestureRecognizer) -> Bool { false }
    }
}

// MARK: - Drawing Canvas
struct DrawingCanvas: View {
    @Binding var paths: [Path]
    @Binding var currentPath: Path
    
    var body: some View {
        Canvas { context, size in
            for path in paths {
                context.stroke(
                    path,
                    with: .color(Color.latinRed),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )
            }
            context.stroke(
                currentPath,
                with: .color(Color.latinRed),
                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            )
        }
        .background(Color.black.opacity(0.001))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let point = value.location
                    if currentPath.isEmpty {
                        currentPath.move(to: point)
                    } else {
                        currentPath.addLine(to: point)
                    }
                }
                .onEnded { _ in
                    if !currentPath.isEmpty {
                        paths.append(currentPath)
                        currentPath = Path()
                    }
                }
        )
    }
}

// MARK: - QR Export Sheet
/// Shares a routine as a QR code or a text code. The code is made here, off the main thread, so the
/// share button always opens this sheet at once, even when the routine is too big for a QR code.
struct QRExportSheet: View {
    let routine: Routine
    @Environment(\.dismiss) private var dismiss

    private enum QRState {
        case loading
        case ready(UIImage)
        case tooLarge
    }

    @State private var state: QRState = .loading
    @State private var payload: String?
    @State private var copyCount = 0
    @State private var showCopied = false

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text(routine.name)
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Text(DanceNames.display(routine.danceName).uppercased())
                                .font(.system(.caption, design: .rounded).weight(.black))
                                .foregroundColor(Color.gold400)
                                .tracking(1.4)
                        }
                        .padding(.top, 8)

                        qrCard

                        Text(explanation)
                            .font(.footnote)
                            .foregroundColor(Color.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        PrimarySheetButton(
                            title: showCopied ? "Skopírované" : "Kopírovať textový kód",
                            isLoading: false,
                            isEnabled: payload != nil,
                            action: copy
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Zdieľať zostavu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavrieť") { dismiss() }
                }
            }
            .task { await build() }
            .task(id: copyCount) {
                guard copyCount > 0 else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showCopied = true }
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeOut(duration: 0.3)) { showCopied = false }
            }
            .sensoryFeedback(.success, trigger: copyCount)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var qrCard: some View {
        ZStack {
            switch state {
            case .loading:
                ProgressView()
                    .tint(Color.gold400)
            case .ready(let image):
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .accessibilityLabel("QR kód zostavy \(routine.name)")
            case .tooLarge:
                VStack(spacing: 10) {
                    Image(systemName: "qrcode")
                        .font(.largeTitle)
                        .foregroundColor(Color.gold400)
                    Text("Zostava je na QR kód príliš veľká")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .transition(.opacity)
            }
        }
        .frame(width: 250, height: 250)
        .homeCard(cornerRadius: 22)
    }

    private var explanation: String {
        switch state {
        case .tooLarge:
            return "Pošli ju ako textový kód: skopíruj ho a na druhom iPhone ho vlož cez QR tlačidlo na Domove."
        default:
            return "Naskenuj QR kód na druhom iPhone, alebo skopíruj textový kód a pošli ho správou."
        }
    }

    private func build() async {
        guard let text = QRGenerator.generatePayload(from: routine) else {
            state = .tooLarge
            return
        }
        payload = text
        let image = await Task.detached(priority: .userInitiated) {
            QRGenerator.generateQRCode(from: text)
        }.value
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            state = image.map(QRState.ready) ?? .tooLarge
        }
    }

    private func copy() {
        guard let payload else { return }
        UIPasteboard.general.string = payload
        copyCount += 1
    }
}

// MARK: - Figure Order Sheet
/// Reorders the figures of a routine by dragging; numbers and the lines on the floor follow at once.
/// A figure added later goes to the end and can be moved where it belongs here.
struct FigureOrderSheet: View {
    let routine: Routine
    var onChange: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var figures: [CanvasNode] = []
    @State private var moveCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                List {
                    Section {
                        ForEach(Array(figures.enumerated()), id: \.element.id) { index, figure in
                            row(figure, number: index + 1)
                                .listRowBackground(Color.white.opacity(0.06))
                                .listRowSeparatorTint(Color.white.opacity(0.08))
                        }
                        .onMove(perform: move)
                    } footer: {
                        Text("Podrž figúru za úchyt vpravo a presuň ju na miesto. Poradie uvidí aj partner.")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle("Poradie figúr")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hotovo") { dismiss() }
                        .fontWeight(.bold)
                        .foregroundColor(.gold400)
                }
            }
            .onAppear { figures = routine.canvasNodes.sorted { $0.orderIndex < $1.orderIndex } }
            .sensoryFeedback(.selection, trigger: moveCount)
        }
        .preferredColorScheme(.dark)
    }

    private func row(_ figure: CanvasNode, number: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.system(.subheadline, design: .rounded).weight(.black))
                .foregroundColor(Color.obsidian900)
                .contentTransition(.numericText())
                .frame(width: 30, height: 30)
                .background(
                    LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Circle()
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(figure.figureName)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                if !figure.rhythm.isEmpty {
                    BeatsTimelineView(rhythm: figure.rhythm, tint: Color.gold500)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(number). \(figure.figureName)")
    }

    private func move(from source: IndexSet, to destination: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            figures.move(fromOffsets: source, toOffset: destination)
        }
        for (index, figure) in figures.enumerated() where figure.orderIndex != index {
            figure.orderIndex = index
        }
        moveCount += 1
        onChange()
    }
}
