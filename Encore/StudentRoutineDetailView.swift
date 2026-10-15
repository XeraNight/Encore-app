import SwiftUI

// MARK: - Student Routine Detail & Coach Inspection View
struct StudentRoutineDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var studioManager = StudioManager.shared
    
    let studentId: UUID
    let studentName: String
    let routine: DBRoutineRow
    
    @State private var nodes: [DBCanvasNodeRow] = []
    @State private var isLoading: Bool = true
    @State private var showAssignFigureSheet: Bool = false
    
    @State private var editingNode: DBCanvasNodeRow? = nil
    @State private var editedNotesText: String = ""
    @State private var showEditNotesDialog: Bool = false
    
    var body: some View {
        ZStack {
            EllegancePageBackground()
            
            VStack(spacing: 0) {
                // Top Header info card
                routineHeaderCard
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 14)
                
                // Action toolbar
                HStack {
                    Text("FIGÚRY V ZOSTAVE (\(nodes.count))")
                        .font(.caption2.weight(.black))
                        .foregroundColor(LuxuryTheme.gold400)
                        .tracking(1.2)
                    
                    Spacer()
                    
                    Button {
                        showAssignFigureSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Priradiť figúru")
                        }
                        .font(.caption.weight(.bold))
                        .foregroundColor(LuxuryTheme.obsidian900)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(LuxuryTheme.gold400)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                
                // List of figures or empty state
                if isLoading {
                    Spacer()
                    ProgressView().tint(LuxuryTheme.gold400)
                    Spacer()
                } else if nodes.isEmpty {
                    emptyFiguresView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(nodes, id: \.id) { node in
                                figureRowView(for: node)
                            }
                            
                            // Bottom security notice
                            securityNoticeView
                                .padding(.top, 16)
                                .padding(.bottom, 30)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 6)
                    }
                    .refreshable {
                        await loadNodes()
                    }
                }
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showAssignFigureSheet) {
            AssignFigureSheetView(
                routineId: routine.id,
                danceName: routine.dance_name,
                studentName: studentName
            ) {
                Task {
                    await loadNodes()
                }
            }
        }
        .sheet(item: $editingNode) { node in
            editNotesSheet(for: node)
        }
        .task {
            await loadNodes()
        }
    }
    
    // MARK: - Routine Header Card
    private var routineHeaderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(routine.dance_category.uppercased())
                            .font(.caption2.weight(.black))
                            .foregroundColor(LuxuryTheme.gold400)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(LuxuryTheme.gold500.opacity(0.18))
                            .cornerRadius(6)
                        
                        Text(routine.dance_name)
                            .font(.footnote.weight(.bold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    Text(routine.name)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Student info
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Zverenec")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.5))
                    Text(studentName)
                        .font(.footnote.weight(.bold))
                        .foregroundColor(.white)
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "pencil.line")
                        .foregroundColor(LuxuryTheme.gold400)
                        .font(.caption2)
                    
                    if let modBy = routine.last_modified_by, !modBy.isEmpty {
                        Text("Upravil: \(modBy)")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.white.opacity(0.75))
                    } else {
                        Text("Pôvodná verzia zverenca")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                Text(routine.updated_at, style: .date)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(LuxuryTheme.obsidian800)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LuxuryTheme.gold500.opacity(0.25), lineWidth: 1))
    }
    
    // MARK: - Figure Row View
    private func figureRowView(for node: DBCanvasNodeRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                // Order badge
                Text("\(node.order_index + 1).")
                    .font(.system(.caption, design: .monospaced).weight(.black))
                    .foregroundColor(LuxuryTheme.gold400)
                    .frame(width: 26, height: 26)
                    .background(LuxuryTheme.gold500.opacity(0.15))
                    .clipShape(Circle())
                
                Text(node.figure_name)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if !node.rhythm.isEmpty {
                    Text(node.rhythm)
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundColor(LuxuryTheme.gold300)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(LuxuryTheme.obsidian900)
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(LuxuryTheme.gold500.opacity(0.3), lineWidth: 1))
                }
            }
            
            // Dancer's own notes (read-only for the coach) and the coach's remark
            if !node.notes.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.caption2)
                        .foregroundColor(LuxuryTheme.gold400)
                        .padding(.top, 2)
                    
                    Text(node.notes)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LuxuryTheme.obsidian900.opacity(0.6))
                .cornerRadius(10)
            }
            
            if let remark = node.coach_notes, !remark.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.caption2)
                        .foregroundColor(LuxuryTheme.gold400)
                        .padding(.top, 2)
                    Text(remark)
                        .font(.footnote.weight(.medium))
                        .foregroundColor(LuxuryTheme.gold300)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LuxuryTheme.gold500.opacity(0.10))
                .cornerRadius(10)
            }

            // Edit coach remark button
            HStack {
                if !node.transition_notes.isEmpty {
                    Text(node.transition_notes)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.45))
                }
                
                Spacer()
                
                Button {
                    editingNode = node
                    editedNotesText = node.coach_notes ?? ""
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text((node.coach_notes ?? "").isEmpty ? "Pridať poznámku trénera" : "Upraviť poznámku trénera")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(LuxuryTheme.gold400)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(LuxuryTheme.obsidian800)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
    }
    
    // MARK: - Empty Figures View
    private var emptyFiguresView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "figure.dance")
                .font(.largeTitle)
                .foregroundColor(LuxuryTheme.gold400.opacity(0.8))
            
            Text("Žiadne figúry v zostave")
                .font(.callout.weight(.bold))
                .foregroundColor(.white)
            
            Text("Zostava je zatiaľ prázdna. Priraď prvú figúru zo svojej trénerskej knižnice.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button {
                showAssignFigureSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Priradiť prvú figúru")
                }
                .font(.subheadline.weight(.bold))
                .foregroundColor(LuxuryTheme.obsidian900)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(LuxuryTheme.gold400)
                .cornerRadius(12)
            }
            .padding(.top, 6)
            Spacer()
        }
    }
    
    // MARK: - Security Notice View
    private var securityNoticeView: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundColor(LuxuryTheme.gold400)
                .font(.callout)
            
            Text("Trénerský režim: úpravy sa hneď zobrazia zverencovi. Zostavu zmazať nemôžeš.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.60))
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(LuxuryTheme.obsidian800.opacity(0.6))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LuxuryTheme.gold500.opacity(0.2), lineWidth: 1))
    }
    
    // MARK: - Edit Notes Sheet
    private func editNotesSheet(for node: DBCanvasNodeRow) -> some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Trénerská poznámka pre: \(node.figure_name)")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    
                    TextField("Napíšte poznámku...", text: $editedNotesText, axis: .vertical)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(4...8)
                        .padding(12)
                        .background(LuxuryTheme.obsidian800)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LuxuryTheme.gold500.opacity(0.3), lineWidth: 1))
                    
                    Spacer()
                    
                    Button {
                        Task {
                            try? await studioManager.updateNodeNotes(
                                routineId: routine.id,
                                nodeId: node.id,
                                coachNotes: editedNotesText
                            )
                            await loadNodes()
                            editingNode = nil
                            HapticFeedback.success()
                        }
                    } label: {
                        Text("Uložiť poznámku")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(LuxuryTheme.obsidian900)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LuxuryTheme.gold400)
                            .cornerRadius(14)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Upraviť poznámku")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zavrieť") {
                        editingNode = nil
                    }
                    .foregroundColor(LuxuryTheme.gold400)
                }
            }
        }
    }
    
    private func loadNodes() async {
        isLoading = true
        let fetched = await studioManager.fetchRoutineNodes(routineId: routine.id)
        self.nodes = fetched
        self.isLoading = false
    }
}

// MARK: - Xcode Canvas Preview
#Preview("StudentRoutineDetailView - Zverenecká Zostava") {
    NavigationStack {
        StudentRoutineDetailView(
            studentId: UUID(),
            studentName: "Viktória Horváthová",
            routine: DBRoutineRow(
                id: UUID(),
                name: "Súťažná Zostava 2026",
                dance_name: "Waltz",
                dance_category: "Standard",
                created_at: Date(),
                updated_at: Date(),
                last_modified_by: "Hlavný Tréner (Peter)"
            )
        )
    }
    .previewWithSampleData()
}
