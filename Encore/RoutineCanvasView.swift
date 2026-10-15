import SwiftUI
import SwiftData
import UIKit
import OSLog
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif

// MARK: - Canvas Card Scale Mode
enum CanvasCardScaleMode: String, CaseIterable, Identifiable {
    case compact = "Kompakt (70%)"
    case normal  = "Štandard (100%)"
    case large   = "Detail (120%)"
    
    var id: String { rawValue }
    
    var scale: CGFloat {
        switch self {
        case .compact: return 0.72
        case .normal:  return 1.0
        case .large:   return 1.20
        }
    }
    
    var icon: String {
        switch self {
        case .compact: return "rectangle.compress.vertical"
        case .normal:  return "rectangle"
        case .large:   return "rectangle.expand.vertical"
        }
    }
    
    var next: CanvasCardScaleMode {
        switch self {
        case .compact: return .normal
        case .normal:  return .large
        case .large:   return .compact
        }
    }
}

struct RoutineCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var routine: Routine
    
    private let canvasSize: CGFloat = 3000
    private let maxScale: CGFloat = 4.5
    
    // Framing & margins around ballroom floor for drawing annotations
    private var annotationMarginX: CGFloat { 48 }
    private var annotationMarginY: CGFloat { 64 }
    
    private var contentWidth: CGFloat {
        BallroomFloorConfig.floorWidth + 2 * annotationMarginX // 840 + 96 = 936 pt
    }
    private var contentHeight: CGFloat {
        BallroomFloorConfig.floorHeight + 2 * annotationMarginY // 1260 + 128 = 1388 pt
    }
    
    /// Fallback size used only for the very first render frame, before GeometryReader
    /// has measured real space. Looked up through the active window scene instead of
    /// UIScreen.main (deprecated in iOS 26 for multi-scene environments).
    private static var fallbackViewportSize: CGSize {
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first {
            let size = window.bounds.size
            if size.width > 0 && size.height > 0 {
                return size
            }
        }
        return CGSize(width: 393, height: 852)
    }
    
    /// Pinch limit when zooming out: a bit further than "whole floor fits", so there is room around it.
    private func computedMinScale(for viewport: CGSize) -> CGFloat {
        max(fitScale(for: viewport) * 0.72, 0.2)
    }

    /// Room taken by the top bar (title, live status) and by the floating controls with "+ Figúra".
    /// A fitted floor sits between them, so no wall label hides under a button.
    private static let reservedTop: CGFloat = 150
    private static let reservedBottom: CGFloat = 215
    private static var fitShiftY: CGFloat { (reservedTop - reservedBottom) / 2 }

    /// Scale at which the whole floor just fits the screen (used by the "fit" buttons).
    private func fitScale(for viewport: CGSize) -> CGFloat {
        let fallback = Self.fallbackViewportSize
        let w = viewport.width > 0 ? viewport.width : fallback.width
        let h = viewport.height > 0 ? viewport.height : fallback.height
        let availableW = max(w - 24, 280)
        let availableH = max(h - Self.reservedTop - Self.reservedBottom, 320)
        let fit = min(availableW / contentWidth, availableH / contentHeight)
        return max(fit, 0.35)
    }
    
    @State private var translation: CGSize = .zero
    @State private var scale: CGFloat = 0.42
    @State private var hasInitializedView: Bool = false
    @State private var viewportSize: CGSize = .zero
    @State private var activelyDraggedNodeIDs: Set<UUID> = []
    @State private var activePan: CGSize = .zero
    @State private var activeZoom: CGFloat = 1.0
    @State private var liveNodePositions: [UUID: CGPoint] = [:]
    
    // Card Customization States (Requested by User)
    @State private var cardScaleMode: CanvasCardScaleMode = .normal
    @State private var isFiguresTranslucent: Bool = false
    
    @State private var showFiguresDrawer = false
    @State private var selectedNodeForEdit: CanvasNode?
    @State private var figureIsWriting = false
    @State private var selectedConnectionForEdit: CanvasConnection?
    
    @Query private var libraryItems: [FigureLibraryItem]
    
    @State private var realtimeManager = CanvasRealtimeManager()
    @State private var isRefreshing = false
    @State private var sketchPaths: [Path] = []
    @State private var currentPath = Path()
    @State private var isDrawingMode = false
    @State private var showQRExport = false
    @State private var showPDFExport = false
    @State private var showRoutineVideoVault = false
    /// Partner moves arrive many times a second; they are written to disk once the partner stops.
    @State private var remoteMoveSaveTask: Task<Void, Never>?
    /// A deleted figure stays hidden (not gone) for a few seconds so it can be brought back.
    @State private var pendingDelete: PendingFigureDelete?
    @State private var pendingDeleteTask: Task<Void, Never>?
    @State private var undoCount = 0
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showFigureOrder = false
    
    @State private var showDuelSheet = false
    @State private var showGuestCoachKeys = false
    
    var isPresentedInTab: Bool = false
    var onBack: (() -> Void)? = nil
    
    @AppStorage("profileName") private var userName = "Tanečník"
    @State private var toastMessage: String? = nil
    @State private var showToast = false
    @State private var toastCount = 0
    
    init(routine: Routine, isPresentedInTab: Bool = false, onBack: (() -> Void)? = nil) {
        self.routine = routine
        self.isPresentedInTab = isPresentedInTab
        self.onBack = onBack
        let danceName = routine.danceName
        self._libraryItems = Query(filter: #Predicate<FigureLibraryItem> { $0.danceName == danceName })
    }
    
    var body: some View {
        let isStandard = routine.danceCategory.lowercased() == "standard"
        let accentColor = isStandard ? Color.standardBlue : Color.latinPink
        let visibleNodes = routine.canvasNodes.filter { $0.id != pendingDelete?.id }
        let numbers = Dictionary(
            uniqueKeysWithValues: visibleNodes.sorted(by: { $0.orderIndex < $1.orderIndex }).enumerated().map { ($1.id, $0 + 1) }
        )
        
        GeometryReader { geo in
            let viewport = geo.size.width > 0 ? geo.size : Self.fallbackViewportSize
            let minScale = computedMinScale(for: viewport)
            let effectiveScale = min(max(scale * activeZoom, minScale), maxScale)
            
            ZStack {
                EllegancePageBackground()
                    .allowsHitTesting(false)
                
                // 1. Gesture Receiver Spanning Edge-to-Edge Viewport (1:1 Touch Tracking for Canvas Pan & Zoom)
                CanvasGestureView(
                    onPanChanged: { delta in
                        guard !isDrawingMode else { return }
                        guard activelyDraggedNodeIDs.isEmpty else { return }
                        activePan = delta
                    },
                    onPanEnded: { delta in
                        guard !isDrawingMode else { return }
                        guard activelyDraggedNodeIDs.isEmpty else { return }
                        translation = clampedTranslation(
                            CGSize(
                                width: translation.width + delta.width,
                                height: translation.height + delta.height
                            ),
                            viewportSize: viewport,
                            scale: effectiveScale
                        )
                        activePan = .zero
                    },
                    onPinchChanged: { zoomFactor in
                        guard !isDrawingMode else { return }
                        activeZoom = zoomFactor
                    },
                    onPinchEnded: { zoomFactor in
                        guard !isDrawingMode else { return }
                        let curMin = computedMinScale(for: viewport)
                        let clamped = min(max(scale * zoomFactor, curMin), maxScale)
                        scale = clamped
                        translation = clampedTranslation(
                            translation,
                            viewportSize: viewport,
                            scale: clamped
                        )
                        activeZoom = 1.0
                    }
                )
                .frame(width: viewport.width, height: viewport.height)
                
                // 2. Scaled Ballroom Canvas Layer (Strictly contained and clipped to Viewport)
                ZStack {
                    ZStack {
                        // 1. Ballroom Real Wood Parquet Floor (4 Planks Grid Squared in Canvas)
                        DanceParquetFloorView(roomSize: canvasSize)
                            .allowsHitTesting(false)
                        
                        // 2. Subtle Precision Grid over Parquet Floor
                        CanvasGridBackground(roomSize: canvasSize)
                            .opacity(0.12)
                            .allowsHitTesting(false)
                        
                        // 3. Golden Ballroom Markings & Long/Short Wall Indicators
                        BallroomMarkingsView(roomSize: canvasSize)
                            .allowsHitTesting(false)
                        
                        if isDrawingMode {
                            DrawingCanvas(paths: $sketchPaths, currentPath: $currentPath)
                                .frame(width: canvasSize, height: canvasSize)
                        }
                        
                        ConnectionsLayer(
                            nodes: visibleNodes,
                            livePositions: liveNodePositions,
                            scale: effectiveScale
                        ) { prevNode, nextNode in
                            selectedConnectionForEdit = CanvasConnection(from: prevNode, to: nextNode)
                        }
                        
                        ForEach(visibleNodes) { node in
                            let lockedBy = realtimeManager.partnerPresences.values.first(where: { $0.draggingNodeId == node.id.uuidString })?.userName
                            CanvasNodeCardView(
                                node: node,
                                number: numbers[node.id] ?? node.orderIndex + 1,
                                scale: effectiveScale,
                                cardScale: cardScaleMode.scale,
                                isTranslucent: isFiguresTranslucent,
                                lockedByUserName: lockedBy
                            ) {
                                selectedNodeForEdit = node
                                updateLiveActivity(with: node)
                            } onDelete: {
                                deleteNode(node)
                            } onDrag: { liveX, liveY in
                                liveNodePositions[node.id] = CGPoint(x: liveX, y: liveY)
                                realtimeManager.broadcastNodeMove(nodeId: node.id, x: liveX, y: liveY)
                                realtimeManager.updatePresence(x: liveX, y: liveY, userName: userName, draggingNodeId: node.id)
                            } onDragStart: {
                                activelyDraggedNodeIDs.insert(node.id)
                            } onDragEnd: { finalX, finalY in
                                activelyDraggedNodeIDs.remove(node.id)
                                liveNodePositions.removeValue(forKey: node.id)
                                routine.updatedAt = Date()
                                routine.lastModifiedBy = userName
                                try? modelContext.save()
                                SupabaseSyncManager.shared.syncRoutineOnBackground(routine)
                                realtimeManager.broadcastNodeMove(nodeId: node.id, x: finalX, y: finalY, force: true)
                                realtimeManager.updatePresence(x: finalX, y: finalY, userName: userName, draggingNodeId: nil)
                            }
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                        
                        if visibleNodes.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "figure.dance")
                                    .font(.system(size: 44, weight: .semibold))
                                    .foregroundColor(accentColor)
                                    .frame(width: 84, height: 84)
                                    .background(accentColor.opacity(0.16), in: Circle())
                                Text("Prázdny parket")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Ťukni na + Figúra a poskladaj zostavu.")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 24)
                            .homeCard(cornerRadius: 24)
                            .shadow(color: Color.black.opacity(0.35), radius: 16, y: 8)
                            .allowsHitTesting(false)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                        }
                    }
                    .frame(width: canvasSize, height: canvasSize)
                    .scaleEffect(effectiveScale, anchor: .center)
                    .offset(canvasOffset(in: viewport, scale: effectiveScale, pan: activePan))
                    
                    // Partner cursors, placed with the same (clamped) offset as the floor
                    let floorOffset = canvasOffset(in: viewport, scale: effectiveScale, pan: activePan)
                    ForEach(Array(realtimeManager.partnerPresences.values), id: \.userId) { presence in
                        PartnerCursorView(name: presence.userName, isDragging: presence.draggingNodeId != nil)
                            .position(
                                x: (presence.x - 1500) * effectiveScale + viewport.width / 2 + floorOffset.width,
                                y: (presence.y - 1500) * effectiveScale + viewport.height / 2 + floorOffset.height
                            )
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: viewport.width, height: viewport.height)
                .clipped()
                
                // ── 3. Floating controls: drawing + AirPlay left, "+ Figúra" centre, view options right ──
                VStack {
                    Spacer()

                    HStack(alignment: .bottom) {
                        VStack(spacing: 12) {
                            AirPlayPickerButton(size: 44)

                            LiquidGlassCircleButton(
                                icon: isDrawingMode ? "pencil.line" : "pencil",
                                label: isDrawingMode ? "Ukončiť kreslenie" : "Kresliť po parkete",
                                isActive: isDrawingMode,
                                activeColor: LuxuryTheme.latinCrimson
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isDrawingMode.toggle() }
                            }
                            .accessibilityIdentifier("canvas.draw")

                            if isDrawingMode && !sketchPaths.isEmpty {
                                LiquidGlassCircleButton(icon: "trash", label: "Zmazať kresbu", size: 38) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { sketchPaths.removeAll() }
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }

                        Spacer()

                        if !isDrawingMode {
                            addFigureButton
                                .accessibilityIdentifier("canvas.addFigure")
                                .transition(.scale(scale: 0.8).combined(with: .opacity))
                        }

                        Spacer()

                        VStack(spacing: 12) {
                            LiquidGlassCircleButton(icon: "scope", label: "Vycentrovať figúry") {
                                fitAllNodes()
                            }
                            .accessibilityIdentifier("canvas.fit")
                            viewOptionsMenu
                                .accessibilityIdentifier("canvas.viewOptions")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, max(geo.safeAreaInsets.bottom + 120, 155))
                    .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isDrawingMode)
                }
                .frame(width: viewport.width, height: viewport.height)

                // ── 4. Top bar: back, title + live status, QR and more ──
                VStack(spacing: 10) {
                    // Buttons sit on the edges; the title is laid over the middle, so it is centred on the
                    // screen (and with the status pill) no matter how many buttons each side has.
                    HStack(alignment: .center, spacing: 10) {
                        LiquidGlassCircleButton(icon: "chevron.left", label: "Späť") {
                            if let onBack { onBack() } else { dismiss() }
                        }
                        .accessibilityIdentifier("canvas.back")

                        Spacer(minLength: 0)

                        LiquidGlassCircleButton(icon: "qrcode", label: "Zdieľať zostavu cez QR kód") {
                            showQRExport = true
                        }
                        .accessibilityIdentifier("canvas.shareQR")

                        moreMenu
                            .accessibilityIdentifier("canvas.more")
                    }
                    .overlay {
                        // Tapping the title renames the routine.
                        Button {
                            renameText = routine.name
                            showRename = true
                        } label: {
                            VStack(spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(routine.name)
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Image(systemName: "pencil")
                                        .font(.caption2.weight(.bold))
                                        .foregroundColor(.white.opacity(0.55))
                                }
                                Text(DanceNames.display(routine.danceName).uppercased())
                                    .font(.system(.caption2, design: .rounded).weight(.black))
                                    .foregroundColor(LuxuryTheme.gold400)
                                    .tracking(1.2)
                                    .lineLimit(1)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable(scale: 0.96))
                        // Two 44 pt buttons + spacing on each side stay free.
                        .frame(maxWidth: max(viewport.width - 2 * (20 + 44 + 10 + 44 + 8), 100))
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityHint("Premenovať zostavu")
                        .accessibilityIdentifier("canvas.rename")
                    }

                    RealtimeStatusPill(isConnected: realtimeManager.isConnected, isSyncing: isRefreshing) {
                        if !realtimeManager.isConnected {
                            realtimeManager.connect(to: routine.id, userName: userName)
                        }
                        guard !isRefreshing else { return }
                        Task { await refreshFromDB(userInitiated: true) }
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, max(geo.safeAreaInsets.top, 54))
                .frame(width: viewport.width, height: viewport.height)

                // "Figúra zmazaná · Vrátiť" above the floating controls
                if let pending = pendingDelete {
                    VStack {
                        Spacer()
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.7))
                            Text("„\(pending.name)“ zmazaná")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Button("Vrátiť", action: undoDelete)
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Color.gold400)
                                .frame(minHeight: 44)
                                .buttonStyle(.pressable)
                                .accessibilityIdentifier("canvas.undoDelete")
                        }
                        .padding(.horizontal, 18)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom + 120, 155) + 62)
                    }
                    .frame(width: viewport.width, height: viewport.height)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Toast under the top bar (same pill as "Uložené" on Home)
                if showToast, let msg = toastMessage {
                    VStack {
                        Label(msg, systemImage: "bell.fill")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .glassEffect(.regular, in: .capsule)
                            .padding(.top, max(geo.safeAreaInsets.top, 54) + 88)
                        Spacer()
                    }
                    .frame(width: viewport.width, height: viewport.height)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
                }
            }
            .frame(width: viewport.width, height: viewport.height)
            .onAppear {
                let initSize = geo.size.width > 0 ? geo.size : Self.fallbackViewportSize
                viewportSize = initSize
                if !hasInitializedView {
                    hasInitializedView = true
                    fitBallroomFloor(in: initSize, animated: false)
                }
            }
            .onChange(of: geo.size) { oldSize, newSize in
                guard newSize.width > 0, newSize.height > 0 else { return }
                viewportSize = newSize
                if !hasInitializedView {
                    hasInitializedView = true
                    fitBallroomFloor(in: newSize, animated: false)
                } else if abs(oldSize.width - newSize.width) > 5 || abs(oldSize.height - newSize.height) > 5 {
                    translation = clampedTranslation(translation, viewportSize: newSize, scale: scale)
                }
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)

        // ─────────────────────────────────────────────────────────────────
        // Part 2 – Auto-refresh po WebSocket reconnecte
        .onChange(of: realtimeManager.needsRefreshAfterReconnect) { _, needs in
            if needs {
                realtimeManager.needsRefreshAfterReconnect = false
                Task { await refreshFromDB() }
                showToastNotification(message: "Spojenie obnovené, sťahujú sa zmeny...")
            }
        }
        .sheet(isPresented: $showDuelSheet) {
            NavigationStack {
                CompareHubView(
                    pathA: $routine.videoPath,
                    pathB: $routine.activeTargetVideoPath,
                    isPresented: $showDuelSheet
                )
            }
        }
        .sheet(isPresented: $showRoutineVideoVault) {
            VideoVaultView(
                routine: routine,
                activeSlotAPath: $routine.videoPath,
                activeSlotBPath: $routine.activeTargetVideoPath
            )
        }
        .sheet(isPresented: $showFiguresDrawer) {
            FiguresDrawerSheet(
                isPresented: $showFiguresDrawer,
                danceName: routine.danceName,
                libraryItems: libraryItems
            ) { selectedItem in
                addFigureToCanvas(selectedItem)
                showFiguresDrawer = false
            }
        }
        // Shown over the canvas instead of pushed: pushing would fire this screen's onDisappear
        // (realtime disconnect, orientation change) and made opening a figure hang.
        .overlay {
            if let node = selectedNodeForEdit {
                FigureDetailCard(
                    node: node,
                    realtimeManager: realtimeManager,
                    onClose: { selectedNodeForEdit = nil },
                    onWritingChange: { figureIsWriting = $0 }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: selectedNodeForEdit?.id)
        .toolbarVisibility(figureIsWriting ? .hidden : .visible, for: .tabBar)
        .sheet(item: $selectedConnectionForEdit) { conn in
            TransitionEditSheet(fromNode: conn.from, toNode: conn.to, realtimeManager: realtimeManager) {
                selectedConnectionForEdit = nil
            }
        }
        .sheet(isPresented: $showPDFExport) {
            RoutinePDFPreviewSheet(routine: routine)
        }
        .sheet(isPresented: $showQRExport) {
            QRExportSheet(routine: routine)
        }
        .sheet(isPresented: $showGuestCoachKeys) {
            GuestCoachKeysSheet(routine: routine)
        }
        .sheet(isPresented: $showFigureOrder) {
            FigureOrderSheet(routine: routine) { routineChangedLocally() }
        }
        .alert("Premenovať zostavu", isPresented: $showRename) {
            TextField("Názov zostavy", text: $renameText)
            Button("Uložiť") { routine.rename(to: renameText, by: userName) }
            Button("Zrušiť", role: .cancel) {}
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: pendingDelete)
        .sensoryFeedback(.warning, trigger: pendingDelete) { _, new in new != nil }
        .sensoryFeedback(.success, trigger: undoCount)
        .disableSwipeBack()
        .task(id: toastCount) {
            // Each new message restarts the 3 s timer instead of being cut short by an older one.
            guard toastCount > 0 else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { showToast = false }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: toastCount)
        .onAppear {
            AppDelegate.orientationLock = .allButUpsideDown
            UIApplication.shared.isIdleTimerDisabled = true
            NavDepth.shared.push()   // hide floating dock while canvas is displayed for full screen ballroom view
            realtimeManager.connect(to: routine.id, userName: userName)
            startLiveActivity()
            
            // 1. Move Node Realtime Handler
            realtimeManager.onNodeMoved = { nodeId, x, y in
                guard !activelyDraggedNodeIDs.contains(nodeId) else { return }
                if let node = routine.canvasNodes.first(where: { $0.id == nodeId }) {
                    withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.82)) {
                        node.x = x
                        node.y = y
                    }
                    scheduleRemoteMoveSave()
                }
            }
            
            // 2. Add Node Realtime Handler
            realtimeManager.onNodeAdded = { node, senderName in
                if !routine.canvasNodes.contains(where: { $0.id == node.id }) {
                    node.routine = routine
                    modelContext.insert(node)
                    try? modelContext.save()
                    showToastNotification(message: "\(senderName) pridal figúru \(node.figureName)")
                }
            }
            
            // 3. Delete Node Realtime Handler
            realtimeManager.onNodeDeleted = { nodeId, figureName, senderName in
                if let node = routine.canvasNodes.first(where: { $0.id == nodeId }) {
                    FigureVideoPlayback.shared.stop(nodeId: nodeId)
                    modelContext.delete(node)
                    try? modelContext.save()
                    showToastNotification(message: "\(senderName) vymazal figúru \(figureName)")
                }
            }
            
            // 3b. Update Node Realtime Handler
            realtimeManager.onNodeUpdated = { updatedNode, senderName in
                if let node = routine.canvasNodes.first(where: { $0.id == updatedNode.id }) {
                    node.notes = updatedNode.notes
                    node.replaceSharedVideoPath(updatedNode.sharedVideoPath)
                    try? modelContext.save()
                    showToastNotification(message: "\(senderName) upravil detaily \(node.figureName)")
                }
            }
            
            // 3c. Update Transition Realtime Handler
            realtimeManager.onTransitionUpdated = { nodeId, transitionNotes, senderName in
                if let node = routine.canvasNodes.first(where: { $0.id == nodeId }) {
                    node.transitionNotes = transitionNotes
                    try? modelContext.save()
                    showToastNotification(message: "\(senderName) upravil prechod")
                }
            }

            // 4a. Postgres Changes – INSERT (záloha ak broadcast chýba, idempotentný)
            realtimeManager.onDBNodeInserted = { row in
                // Broadcast príde ~50ms, Postgres Change ~200-500ms – guard zabraňuje duplikátu
                guard !routine.canvasNodes.contains(where: { $0.id == row.id }) else { return }
                let node = CanvasNode(row: row)
                node.routine = routine
                modelContext.insert(node)
                try? modelContext.save()
            }

            // 4b. Postgres Changes – UPDATE (aktualizuje polia existujúceho nodu)
            realtimeManager.onDBNodeUpdated = { row in
                guard !activelyDraggedNodeIDs.contains(row.id) else { return }
                guard let node = routine.canvasNodes.first(where: { $0.id == row.id }) else { return }
                node.apply(row: row, includingPosition: true)
                try? modelContext.save()
            }

            // 4c. Postgres Changes – DELETE (vyžaduje REPLICA IDENTITY FULL v Supabase)
            realtimeManager.onDBNodeDeleted = { nodeId in
                guard let node = routine.canvasNodes.first(where: { $0.id == nodeId }) else { return }
                modelContext.delete(node)
                try? modelContext.save()
            }

            // 5. Initial Sync with Supabase Database on connection
            Task {
                if let (dbRoutine, dbNodes) = await SupabaseSyncManager.shared.fetchRoutine(routine.id) {
                    // Check if DB version is newer
                    if dbRoutine.updated_at > routine.updatedAt {
                        await MainActor.run {
                            routine.name = dbRoutine.name
                            routine.danceName = dbRoutine.dance_name
                            routine.danceCategory = dbRoutine.dance_category
                            routine.updatedAt = dbRoutine.updated_at
                            routine.lastModifiedBy = dbRoutine.last_modified_by
                            reconcileNodes(with: dbNodes)
                            Logger.canvas.info("Routine fully synchronized with remote DB.")
                        }
                    }
                }
            }
        }
        .onDisappear {
            AppDelegate.orientationLock = .portrait
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
            }
            UIApplication.shared.isIdleTimerDisabled = false
            remoteMoveSaveTask?.cancel()
            try? modelContext.save()
            commitPendingDelete()
            NavDepth.shared.pop()    // restore floating dock when leaving canvas
            realtimeManager.disconnect()
            stopLiveActivity()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && (oldPhase == .background || oldPhase == .inactive) {
                if !realtimeManager.isConnected {
                    realtimeManager.connect(to: routine.id, userName: userName)
                }
                Task {
                    await refreshFromDB(userInitiated: false)
                }
            }
        }
    }
    
    // MARK: - Manual DB Refresh (refresh button, no need to leave canvas)

    private func refreshFromDB(userInitiated: Bool = false) async {
        isRefreshing = true
        defer {
            Task { @MainActor in isRefreshing = false }
        }
        guard let (_, dbNodes) = await SupabaseSyncManager.shared.fetchRoutine(routine.id) else { return }

        await MainActor.run {
            reconcileNodes(with: dbNodes)
            if userInitiated {
                showToastNotification(message: "Zostava obnovená ✓")
            }
        }
    }

    /// Brings the figures in line with the server in place. Figures are never recreated, so local-only
    /// data (the original video, formatting, rotation, the video vault) survives every sync.
    /// An empty answer never wipes local figures.
    private func reconcileNodes(with dbNodes: [DBCanvasNodeRow]) {
        guard !dbNodes.isEmpty || routine.canvasNodes.isEmpty else { return }
        var existingMap = Dictionary(routine.canvasNodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var newNodes: [CanvasNode] = []

        for dbNode in dbNodes {
            if let existing = existingMap.removeValue(forKey: dbNode.id) {
                existing.apply(row: dbNode, includingPosition: !activelyDraggedNodeIDs.contains(existing.id))
                newNodes.append(existing)
            } else {
                let node = CanvasNode(row: dbNode)
                node.routine = routine
                modelContext.insert(node)
                newNodes.append(node)
            }
        }

        for leftover in existingMap.values {
            modelContext.delete(leftover)
        }
        routine.canvasNodes = newNodes
        try? modelContext.save()
    }

    private func scheduleRemoteMoveSave() {
        remoteMoveSaveTask?.cancel()
        remoteMoveSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            try? modelContext.save()
        }
    }

    private func showToastNotification(message: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            toastMessage = message
            showToast = true
        }
        toastCount += 1
    }

    // MARK: - Floating controls

    /// The main action on the canvas, always in reach above the tab bar.
    private var addFigureButton: some View {
        Button { showFiguresDrawer = true } label: {
            Label("Figúra", systemImage: "plus")
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color.obsidian900)
                .padding(.horizontal, 20)
                .frame(minHeight: 46)
                .background(
                    LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: Capsule()
                )
                .shadow(color: Color.black.opacity(0.3), radius: 12, y: 5)
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.impact(weight: .medium), trigger: showFiguresDrawer)
        .accessibilityLabel("Pridať figúru")
    }

    /// Card size and see-through cards, in one menu instead of two buttons.
    private var viewOptionsMenu: some View {
        Menu {
            Picker("Veľkosť figúr", selection: $cardScaleMode) {
                ForEach(CanvasCardScaleMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                }
            }
            Toggle(isOn: $isFiguresTranslucent) {
                Label("Priesvitné karty", systemImage: "square.2.layers.3d")
            }
        } label: {
            GlassCircleLabel(icon: "slider.horizontal.3")
        }
        .sensoryFeedback(.selection, trigger: cardScaleMode)
        .sensoryFeedback(.selection, trigger: isFiguresTranslucent)
        .accessibilityLabel("Zobrazenie figúr")
    }

    private var moreMenu: some View {
        Menu {
            Button { showDuelSheet = true } label: {
                Label("Duel videí", systemImage: "rectangle.split.2x1.fill")
            }
            Button { showRoutineVideoVault = true } label: {
                Label("Videá a fotky zostavy", systemImage: "photo.stack.fill")
            }
            Button { showGuestCoachKeys = true } label: {
                Label("Hosťujúci tréner", systemImage: "key.fill")
            }
            Button { showFigureOrder = true } label: {
                Label("Poradie figúr", systemImage: "list.number")
            }
            .disabled(routine.canvasNodes.count < 2)
        } label: {
            GlassCircleLabel(icon: "ellipsis")
        }
        .accessibilityLabel("Ďalšie akcie")
    }
    
    // MARK: - Canvas Math
    
    private func canvasOffset(in viewportSize: CGSize, scale: CGFloat, pan: CGSize) -> CGSize {
        return clampedTranslation(
            CGSize(
                width: translation.width + pan.width,
                height: translation.height + pan.height
            ),
            viewportSize: viewportSize,
            scale: scale
        )
    }
    
    private func clampedTranslation(_ proposed: CGSize, viewportSize: CGSize, scale: CGFloat) -> CGSize {
        guard viewportSize.width > 0, viewportSize.height > 0 else { return proposed }
        let scaledCanvas = canvasSize * scale
        let horizontalLimit = max(200.0, scaledCanvas / 2 + viewportSize.width / 2 - 120)
        let verticalLimit   = max(200.0, scaledCanvas / 2 + viewportSize.height / 2 - 120)
        return CGSize(
            width:  min(max(proposed.width,  -horizontalLimit), horizontalLimit),
            height: min(max(proposed.height, -verticalLimit),   verticalLimit)
        )
    }
    
    // MARK: - Canvas Actions
    
    private func addFigureToCanvas(_ item: FigureLibraryItem) {
        let sorted = routine.canvasNodes.sorted(by: { $0.orderIndex < $1.orderIndex })
        let nextIndex = sorted.count
        
        // Compute safe spawn bounds strictly within the parquet floor
        let cardW = 140.0 * cardScaleMode.scale
        let cardH = 132.0 * cardScaleMode.scale
        let bounds = BallroomFloorConfig.safeCardBounds(
            cardWidth: cardW,
            cardHeight: cardH,
            wallMargin: 20
        )
        
        let cols = 3
        let col = nextIndex % cols
        let row = (nextIndex / cols) % 5
        let stepX = (bounds.maxX - bounds.minX) / CGFloat(max(cols - 1, 1))
        let stepY = min(150.0, (bounds.maxY - bounds.minY) / 5.0)
        
        let spawnX = min(max(bounds.minX + CGFloat(col) * stepX, bounds.minX), bounds.maxX)
        let spawnY = min(max(bounds.minY + CGFloat(row) * stepY, bounds.minY), bounds.maxY)
        
        let node = CanvasNode(
            x: Double(spawnX),
            y: Double(spawnY),
            figureName: item.name,
            rhythm: item.rhythm,
            notes: item.techniqueNotes,
            orderIndex: nextIndex
        )
        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
            routine.canvasNodes.append(node)
        }
        routine.updatedAt = Date()
        routine.lastModifiedBy = userName
        try? modelContext.save()
        SupabaseSyncManager.shared.syncRoutineOnBackground(routine)
        realtimeManager.broadcastNodeAdded(node: node, senderName: userName)
    }
    
    /// Hides the figure and offers "Vrátiť" for a few seconds; only then is it really deleted.
    private func deleteNode(_ node: CanvasNode) {
        commitPendingDelete()
        FigureVideoPlayback.shared.stop(nodeId: node.id)
        pendingDelete = PendingFigureDelete(id: node.id, name: node.figureName)
        pendingDeleteTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            commitPendingDelete()
        }
    }

    private func undoDelete() {
        pendingDeleteTask?.cancel()
        pendingDeleteTask = nil
        pendingDelete = nil
        undoCount += 1
    }

    private func commitPendingDelete() {
        pendingDeleteTask?.cancel()
        pendingDeleteTask = nil
        guard let pending = pendingDelete else { return }
        pendingDelete = nil
        guard let node = routine.canvasNodes.first(where: { $0.id == pending.id }) else { return }

        if let videoPath = node.videoPath {
            MediaStorageManager.removeFile(named: videoPath)
        }
        modelContext.delete(node)
        // The relationship may still list the deleted figure until the next save.
        let remaining = routine.canvasNodes
            .filter { $0.id != pending.id }
            .sorted(by: { $0.orderIndex < $1.orderIndex })
        for (index, figure) in remaining.enumerated() { figure.orderIndex = index }
        routineChangedLocally()
        realtimeManager.broadcastNodeDeleted(nodeId: pending.id, figureName: pending.name, senderName: userName)
    }

    /// Saves, marks the routine as changed by this user and syncs it.
    private func routineChangedLocally() {
        routine.updatedAt = Date()
        routine.lastModifiedBy = userName
        try? modelContext.save()
        SupabaseSyncManager.shared.syncRoutineOnBackground(routine)
    }
    
    /// Fits the entire ballroom floor within the user's viewport with comfortable padding,
    /// ensuring the full wooden floor, golden outer border, and left/right wall markings are immediately visible.
    private func fitBallroomFloor(in viewport: CGSize, animated: Bool = true) {
        guard viewport.width > 0, viewport.height > 0 else { return }
        let targetScale = fitScale(for: viewport)
        
        let centred = CGSize(width: 0, height: Self.fitShiftY)
        if animated {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                scale = targetScale
                translation = centred
            }
        } else {
            scale = targetScale
            translation = centred
        }
    }
    
    private func fitAllNodes() {
        let nodes = routine.canvasNodes
        guard !nodes.isEmpty else {
            fitBallroomFloor(in: viewportSize)
            return
        }
        
        let minS = fitScale(for: viewportSize)
        
        // Include node bounds as well as ballroom center anchor
        let xs = nodes.map { $0.x } + [BallroomFloorConfig.centerPoint.x - BallroomFloorConfig.floorWidth * 0.40, BallroomFloorConfig.centerPoint.x + BallroomFloorConfig.floorWidth * 0.40]
        let ys = nodes.map { $0.y } + [BallroomFloorConfig.centerPoint.y - BallroomFloorConfig.floorHeight * 0.40, BallroomFloorConfig.centerPoint.y + BallroomFloorConfig.floorHeight * 0.40]
        let minX = xs.min() ?? 1150.0, maxX = xs.max() ?? 1850.0
        let minY = ys.min() ?? 950.0,  maxY = ys.max() ?? 2050.0
        let centerX = (minX + maxX) / 2.0
        let centerY = (minY + maxY) / 2.0
        let boundsWidth  = max(maxX - minX + 60, contentWidth)
        let boundsHeight = max(maxY - minY + 60, contentHeight)
        let availableWidth  = max(viewportSize.width  - 24,  280)
        let availableHeight = max(viewportSize.height - Self.reservedTop - Self.reservedBottom, 320)
        let targetScale = min(max(min(availableWidth / boundsWidth, availableHeight / boundsHeight), minS), maxScale)
        
        withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
            scale = targetScale
            translation = clampedTranslation(
                CGSize(
                    width:  CGFloat(1500.0 - centerX) * targetScale,
                    height: CGFloat(1500.0 - centerY) * targetScale + Self.fitShiftY
                ),
                viewportSize: viewportSize,
                scale: targetScale
            )
        }
    }
    
    // MARK: - Live Activity Management
    
    #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        stopLiveActivity()
        
        let attributes = EncoreAttributes(
            routineName: routine.name,
            danceName: routine.danceName
        )
        
        let sortedNodes = routine.canvasNodes.sorted(by: { $0.orderIndex < $1.orderIndex })
        let currentName = sortedNodes.first?.figureName ?? "Spustenie zostavy"
        let nextName = sortedNodes.count > 1 ? sortedNodes[1].figureName : ""
        
        let initialState = EncoreAttributes.ContentState(
            currentFigureName: currentName,
            nextFigureName: nextName,
            currentFigureIndex: sortedNodes.isEmpty ? 0 : 1,
            totalFigures: sortedNodes.count,
            lastUpdated: Date()
        )
        
        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            Logger.canvas.info("Live Activity started.")
        } catch {
            Logger.canvas.error("Live Activity start failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func updateLiveActivity(with node: CanvasNode) {
        let sortedNodes = routine.canvasNodes.sorted(by: { $0.orderIndex < $1.orderIndex })
        guard let index = sortedNodes.firstIndex(where: { $0.id == node.id }) else { return }
        
        let currentName = node.figureName
        let nextName = (index + 1 < sortedNodes.count) ? sortedNodes[index + 1].figureName : ""
        
        let updatedState = EncoreAttributes.ContentState(
            currentFigureName: currentName,
            nextFigureName: nextName,
            currentFigureIndex: index + 1,
            totalFigures: sortedNodes.count,
            lastUpdated: Date()
        )
        
        Task {
            for activity in Activity<EncoreAttributes>.activities {
                if activity.attributes.routineName == routine.name {
                    await activity.update(.init(state: updatedState, staleDate: nil))
                }
            }
        }
    }
    
    private func stopLiveActivity() {
        Task {
            for activity in Activity<EncoreAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    #else
    private func startLiveActivity() {}
    private func updateLiveActivity(with node: CanvasNode) {}
    private func stopLiveActivity() {}
    #endif
}

/// The figure waiting to be deleted while "Vrátiť" is offered.
private struct PendingFigureDelete: Equatable {
    let id: UUID
    let name: String
}
