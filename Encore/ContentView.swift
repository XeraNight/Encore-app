import SwiftUI
import SwiftData

// MARK: - Home ("Domov")
/// Composes the Home sections: logo hub, note capture, notes and the last edited routine.
/// Each section is its own view; this one only owns navigation and the sheets opened from Home.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Routine.updatedAt, order: .reverse, animation: .easeInOut) private var routines: [Routine]
    @Query(filter: #Predicate<InstantNote> { $0.importedAt == nil },
           sort: \InstantNote.createdAt, order: .reverse) private var inboxNotes: [InstantNote]
    @Query(sort: \FigureLibraryItem.name) private var allFigures: [FigureLibraryItem]

    // Capture
    @State private var isTyping = false
    @State private var showCameraModal = false
    @State private var showNotesInbox = false
    @State private var noteToEdit: InstantNote?
    @State private var refreshCount = 0

    // Logo hub & command palette
    @State private var isRadialHubOpen = false
    @State private var showLogoCommandPalette = false

    // Sheets opened from the hub or the palette
    @State private var showNewRoutineCategorySheet = false
    @State private var showDanceMirrorModal = false
    @State private var showMetronomeSheet = false
    @State private var showCompareModeSheet = false
    @State private var showGlobalLibrarySheet = false
    @State private var showAllRoutinesSheet = false
    @State private var selectedRoutineForNavigation: Routine?
    @State private var compareSlotAPath: String?
    @State private var compareSlotBPath: String?

    // Routine import (QR / pasted code) and guest coach keys
    @ObservedObject private var guestService = GuestCoachService.shared
    @State private var showQRScanner = false
    @State private var scanErrorMessage: String?
    @State private var showScanError = false
    @State private var showScanSuccess = false
    @State private var scannedRoutineName = ""
    @State private var showManualCodeSheet = false
    @State private var manualCodeInput = ""

    /// Pinned notes first, then newest.
    private var sortedInbox: [InstantNote] {
        inboxNotes.sorted { ($0.isPinned ? 1 : 0, $0.createdAt) > ($1.isPinned ? 1 : 0, $1.createdAt) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                // Tap outside closes the open logo hub.
                if isRadialHubOpen {
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                isRadialHubOpen = false
                            }
                        }
                        .zIndex(20)
                        .accessibilityLabel("Zavrieť rýchle akcie")
                        .accessibilityAddTraits(.isButton)
                }

                GeometryReader { geo in
                    let logoSize: CGFloat = geo.size.width < 380 ? 78 : 92
                    let fieldHeight = max(geo.size.height * 0.30, 220)
                    let safeTop = max(geo.safeAreaInsets.top, 44)

                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 18) {
                                workspaceTopHeader(logoSize: logoSize)
                                    .padding(.top, safeTop - 24)
                                    .zIndex(isRadialHubOpen ? 100 : 1)
                                    // Fade out while it scrolls under the status bar instead of being cut off.
                                    .scrollTransition(.animated(.easeOut(duration: 0.15))) { content, phase in
                                        content.opacity(phase.isIdentity ? 1 : 0)
                                    }

                                HomeCaptureWorkspace(
                                    fieldHeight: fieldHeight,
                                    isTyping: $isTyping,
                                    isCameraPresented: $showCameraModal
                                )
                                .id("capture")
                                .zIndex(isRadialHubOpen ? 0 : 2)

                                NotesInboxStrip(
                                    notes: sortedInbox,
                                    onOpenAll: { showNotesInbox = true },
                                    onOpenNote: { noteToEdit = $0 }
                                )

                                LessonPrioritiesSection(showsWhenEmpty: false)

                                if let recent = routines.first {
                                    HomeRecentRoutineCard(routine: recent) {
                                        selectedRoutineForNavigation = recent
                                    }
                                }

                                // Room for the tab bar
                                Spacer().frame(height: 120)
                            }
                            .padding(.horizontal, 20)
                            .frame(maxWidth: .infinity)
                            // Tapping anywhere outside the field closes the keyboard.
                            .background {
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture { isTyping = false }
                            }
                        }
                        .scrollDisabled(isRadialHubOpen)
                        .scrollDismissesKeyboard(.interactively)
                        .refreshable {
                            refreshCount += 1
                            UserProfileStore.shared.refreshForActiveUser()
                            await AuthManager.shared.checkCurrentSession()
                            await SupabaseSyncManager.shared.pullRoutines(into: modelContext)
                        }
                        // The page stays where it is; it only moves by the few points needed
                        // when part of the field is scrolled out of view.
                        .onChange(of: isTyping) { _, typing in
                            guard typing else { return }
                            withAnimation(.smooth(duration: 0.35)) {
                                proxy.scrollTo("capture")
                            }
                        }
                    }
                }
            }
            .environment(\.locale, Locale(identifier: "sk"))
            .toolbar(.hidden, for: .navigationBar)
            .sensoryFeedback(.impact(weight: .medium), trigger: refreshCount)
            .navigationDestination(item: $selectedRoutineForNavigation) { routine in
                RoutineCanvasView(routine: routine)
            }
            .sheet(isPresented: $showLogoCommandPalette) {
                LogoCommandPaletteView(
                    isPresented: $showLogoCommandPalette,
                    onSelectNewRoutine: { showNewRoutineCategorySheet = true },
                    onSelectCompare: { showCompareModeSheet = true },
                    onSelectLibrary: { showGlobalLibrarySheet = true },
                    onSelectCanvas: { showAllRoutinesSheet = true },
                    onSelectCamera: { showCameraModal = true },
                    onSelectScanQR: { showQRScanner = true },
                    onSelectRoutine: { selectedRoutineForNavigation = $0 },
                    routines: routines,
                    allFigures: allFigures
                )
                .presentationDetents([.fraction(0.85), .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showNotesInbox) {
                NotesInboxSheet()
            }
            .sheet(item: $noteToEdit) { note in
                NoteDetailSheet(note: note)
            }
            .sheet(isPresented: $showNewRoutineCategorySheet) {
                NavigationStack {
                    DanceCategorySelectionSheet(isPresented: $showNewRoutineCategorySheet)
                }
            }
            .sheet(isPresented: $showCompareModeSheet) {
                NavigationStack {
                    CompareHubView(
                        pathA: $compareSlotAPath,
                        pathB: $compareSlotBPath,
                        isPresented: $showCompareModeSheet
                    )
                }
            }
            .sheet(isPresented: $showGlobalLibrarySheet) {
                GlobalLibraryView()
            }
            .sheet(isPresented: $showAllRoutinesSheet) {
                AllRoutinesSheetView(
                    routines: routines,
                    onSelectRoutine: { routine in
                        showAllRoutinesSheet = false
                        selectedRoutineForNavigation = routine
                    },
                    onNewRoutine: {
                        showAllRoutinesSheet = false
                        showNewRoutineCategorySheet = true
                    }
                )
            }
            .fullScreenCover(isPresented: $showDanceMirrorModal) {
                DanceMirrorView()
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showMetronomeSheet) {
                DanceMetronomeView()
            }
            .qrScanner(isPresented: $showQRScanner, onScan: handleScannedCode)
            .sheet(isPresented: Binding(
                get: { guestService.pendingToken != nil },
                set: { if !$0 { guestService.pendingToken = nil } }
            )) {
                if let token = guestService.pendingToken {
                    GuestKeyRedeemView(token: token)
                }
            }
            .sheet(isPresented: $showManualCodeSheet) {
                manualCodeImportSheet
            }
            .alert("Chyba skenovania", isPresented: $showScanError, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(scanErrorMessage ?? "Neznáma chyba")
            })
            .alert("Zostava naimportovaná", isPresented: $showScanSuccess, actions: {
                Button("Skvelé", role: .cancel) {}
            }, message: {
                Text("Zostava \"\(scannedRoutineName)\" bola úspešne naimportovaná.")
            })
        }
    }

    // MARK: - 1. Top Minimal Header with Centered Pure Gold Logo & Interactive Radial Hub
    private func workspaceTopHeader(logoSize: CGFloat) -> some View {
        ZStack {
            // ── Interactive Encore Radial Hub (Logo + Drag-to-Select Satellite Buttons) ──
            EncoreRadialHubView(
                isOpen: $isRadialHubOpen,
                logoSize: logoSize,
                onSelectAction: { action in
                    handleRadialAction(action)
                },
                onTogglePaletteFallback: {
                    showLogoCommandPalette = true
                }
            )
        }
        .frame(maxWidth: .infinity)
        // Open height must equal the hub's own frame (EncoreRadialHubView) so nothing overflows
        // onto the text field below; closed, the header stays slim.
        .frame(height: isRadialHubOpen ? max(logoSize + 185, 300) : logoSize + 36)
        .overlay(alignment: .topTrailing) {
            // Right QR Scanner & Actions Menu (Single Apple 3D Liquid Glass Lens)
            Menu {
                Button(action: { showQRScanner = true }) {
                    Label("Skenovať QR kód", systemImage: "qrcode.viewfinder")
                }
                Button(action: {
                    if let str = UIPasteboard.general.string, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        handleScannedCode(str)
                    } else {
                        showError("Nemáš skopírovaný žiadny kód zostavy.")
                    }
                }) {
                    Label("Vložiť skopírovaný kód", systemImage: "doc.on.clipboard")
                }
                Button(action: { showManualCodeSheet = true }) {
                    Label("Zadať kód manuálne", systemImage: "keyboard")
                }
            } label: {
                GlassCircleLabel(icon: "qrcode.viewfinder")
            }
            .accessibilityLabel("Importovať zostavu")
            .accessibilityHint("Naskenuj QR kód alebo vlož kód zostavy")
            .padding(.trailing, 2)
            .opacity(isRadialHubOpen ? 0.0 : 1.0)
            .animation(.easeOut(duration: 0.18), value: isRadialHubOpen)
        }
    }
    
    // MARK: - Radial Action Dispatcher
    private func handleRadialAction(_ action: RadialHubAction) {
        switch action {
        case .newRoutine:
            showNewRoutineCategorySheet = true
        case .mirror:
            showDanceMirrorModal = true
            AnalyticsManager.shared.mirrorOpened(source: "radial_hub")
        case .metronome:
            showMetronomeSheet = true
        case .compare:
            showCompareModeSheet = true
        }
    }
    
    // MARK: - Routine import
    private func handleScannedCode(_ rawCode: String) {
        if AppFeatures.coachTools, let token = GuestCoachLink.token(from: rawCode) {
            guestService.pendingToken = token
            return
        }
        do {
            scannedRoutineName = try RoutineShareImporter.importRoutine(fromCode: rawCode, into: modelContext)
            showScanSuccess = true
        } catch {
            showError((error as? LocalizedError)?.errorDescription ?? "Nepodarilo sa naimportovať zostavu.")
        }
    }

    private func showError(_ message: String) {
        scanErrorMessage = message
        showScanError = true
    }

    private var manualCodeImportSheet: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Skopíruj textový kód zostavy z druhého iPhonu a vlož ho sem.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)

                    TextEditor(text: $manualCodeInput)
                        .scrollContentBackground(.hidden)
                        .font(.callout.monospaced())
                        .foregroundColor(.white)
                        .frame(height: 150)
                        .padding(10)
                        .homeCard(cornerRadius: 16)

                    PrimarySheetButton(
                        title: "Naimportovať zostavu",
                        isLoading: false,
                        isEnabled: !manualCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        let codeToProcess = manualCodeInput
                        manualCodeInput = ""
                        showManualCodeSheet = false
                        handleScannedCode(codeToProcess)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Kód zostavy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zrušiť") { showManualCodeSheet = false }
                        .foregroundColor(.gold400)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Xcode Canvas Preview
#Preview("Domov") {
    ContentView()
        .previewWithSampleData()
}
