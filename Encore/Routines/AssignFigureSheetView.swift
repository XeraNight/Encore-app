import SwiftUI
import SwiftData

// MARK: - Assign Figure From Coach Library to Student Routine Sheet
struct AssignFigureSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FigureLibraryItem.name) private var libraryFigures: [FigureLibraryItem]
    
    let routineId: UUID
    let danceName: String
    let studentName: String
    let onAssigned: () -> Void
    
    @State private var searchQuery: String = ""
    @State private var selectedFigure: FigureLibraryItem? = nil
    @State private var customFigureName: String = ""
    @State private var rhythm: String = ""
    @State private var coachNotes: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    
    private var filteredFigures: [FigureLibraryItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return libraryFigures.filter { fig in
            // Filter by dance name if matching, or show all if search query is present
            let matchesDance = fig.danceName.lowercased() == danceName.lowercased()
            if query.isEmpty {
                return matchesDance
            }
            return (matchesDance || query.count >= 2) && (fig.name.lowercased().contains(query) || fig.danceName.lowercased().contains(query))
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header info
                        headerInfoSection
                        
                        // Figure Selection
                        figureSelectionSection
                        
                        // Technical notes & rhythm
                        customizationSection
                        
                        // Error message
                        if let error = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.latinCrimson)
                                Text(error)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(Color.latinCrimson.opacity(0.15))
                            .cornerRadius(12)
                        }
                        
                        // Assign Button
                        assignActionButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Priradiť figúru")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zrušiť") {
                        dismiss()
                    }
                    .foregroundColor(LuxuryTheme.gold400)
                }
            }
        }
    }
    
    // MARK: - Header Info
    private var headerInfoSection: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "graduationcap.fill")
                    .foregroundColor(LuxuryTheme.gold400)
                Text("KNIŽNICA TRÉNERA")
                    .font(.caption2.weight(.black))
                    .foregroundColor(LuxuryTheme.gold400)
                    .tracking(1.2)
            }
            
            Text("Pridanie figúry pre: \(studentName)")
                .font(.callout.weight(.bold))
                .foregroundColor(.white)
            
            Text("Tanec: \(danceName)")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(LuxuryTheme.obsidian800)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LuxuryTheme.gold500.opacity(0.25), lineWidth: 1))
    }
    
    // MARK: - Figure Selection Section
    private var figureSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VYBER FIGÚRU Z KNIŽNICE")
                .font(.caption2.weight(.black))
                .foregroundColor(LuxuryTheme.gold400)
                .tracking(1.2)
            
            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.4))
                TextField("Hľadať figúru...", text: $searchQuery)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(LuxuryTheme.obsidian800)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
            
            // Filtered Figure Chips / List
            if filteredFigures.isEmpty {
                VStack(spacing: 8) {
                    Text("V knižnici pre \(danceName) nie sú žiadne uložené figúry.")
                        .font(.footnote)
                        .foregroundColor(Color.textSecondary)
                    
                    TextField("Vlastný názov figúry", text: $customFigureName)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(LuxuryTheme.obsidian800)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LuxuryTheme.gold500.opacity(0.3), lineWidth: 1))
                }
                .padding(.top, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filteredFigures, id: \.id) { fig in
                            let isSelected = selectedFigure?.id == fig.id
                            Button {
                                selectedFigure = fig
                                customFigureName = ""
                                if rhythm.isEmpty { rhythm = fig.rhythm }
                                if coachNotes.isEmpty { coachNotes = fig.techniqueNotes }
                                HapticFeedback.light()
                            } label: {
                                Text(fig.name)
                                    .font(.footnote.weight(isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? LuxuryTheme.obsidian900 : .white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? LuxuryTheme.gold400 : LuxuryTheme.obsidian800)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isSelected ? LuxuryTheme.gold400 : Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    // MARK: - Customization Section
    private var customizationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PARAMETRE PRE ZVERENCA")
                .font(.caption2.weight(.black))
                .foregroundColor(LuxuryTheme.gold400)
                .tracking(1.2)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Rytmizácia (napr. 1 2 3, SQQ, 1 a 2)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
                
                TextField("Napr. 1 2 3", text: $rhythm)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(LuxuryTheme.obsidian800)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Trénerská poznámka / Pokyny k technike")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.7))
                
                TextField("Napr. Udržuj stály kontakt v ráme a klesaj až na konci doby 3.", text: $coachNotes, axis: .vertical)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .lineLimit(3...5)
                    .padding(12)
                    .background(LuxuryTheme.obsidian800)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
        }
    }
    
    // MARK: - Action Button
    private var assignActionButton: some View {
        let name = selectedFigure?.name ?? customFigureName.trimmingCharacters(in: .whitespacesAndNewlines)
        let canAssign = !name.isEmpty && !isSubmitting
        
        return Button {
            submitAssignment(figName: name)
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView().tint(LuxuryTheme.obsidian900)
                } else {
                    Image(systemName: "plus.circle.fill")
                    Text("Vložiť do zostavy zverenca")
                }
            }
            .font(.subheadline.weight(.bold))
            .foregroundColor(LuxuryTheme.obsidian900)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canAssign ? LuxuryTheme.gold400 : Color.gray.opacity(0.5))
            .cornerRadius(14)
        }
        .disabled(!canAssign)
        .buttonStyle(.plain)
    }
    
    private func submitAssignment(figName: String) {
        guard !figName.isEmpty else { return }
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await StudioManager.shared.assignFigureToStudentRoutine(
                    routineId: routineId,
                    figureName: figName,
                    rhythm: rhythm,
                    coachNotes: coachNotes
                )
                HapticFeedback.success()
                onAssigned()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
                HapticFeedback.error()
            }
        }
    }
}
