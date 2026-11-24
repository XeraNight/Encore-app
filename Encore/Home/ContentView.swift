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

    // Capture
    @State private var isTyping = false
    @State private var showCameraModal = false
    @State private var showNotesInbox = false
    @State private var noteToEdit: InstantNote?
    @State private var refreshCount = 0

    // Logo hub & command palette
    @State private var isRadialHubOpen = false

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

    // A guest coach key opened from a link (FriendManager.handleScanned)
    @ObservedObject private var guestService = GuestCoachService.shared

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
                            UserProfileStore.shared.refreshForActiveUser(force: true)
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
            .overlay(alignment: .top) { OfflinePill() }
            .toolbar(.hidden, for: .navigationBar)
            .sensoryFeedback(.impact(weight: .medium), trigger: refreshCount)
            .navigationDestination(item: $selectedRoutineForNavigation) { routine in
                RoutineCanvasView(routine: routine)
            }
            .sheet(isPresented: $showNotesInbox) {
                TrainingJournalView()
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
            .sheet(isPresented: Binding(
                get: { guestService.pendingToken != nil },
                set: { if !$0 { guestService.pendingToken = nil } }
            )) {
                if let token = guestService.pendingToken {
                    GuestKeyRedeemView(token: token)
                }
            }
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
                }
            )
        }
        .frame(maxWidth: .infinity)
        // Open height must equal the hub's own frame (EncoreRadialHubView) so nothing overflows
        // onto the text field below; closed, the header stays slim.
        .frame(height: isRadialHubOpen ? max(logoSize + 185, 300) : logoSize + 36)
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
}

// MARK: - Xcode Canvas Preview
#Preview("Domov") {
    ContentView()
        .previewWithSampleData()
}
