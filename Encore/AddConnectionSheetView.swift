import SwiftUI

// MARK: - Add Dancer Connection Sheet (Search by Dancer ID or Name)
struct AddConnectionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var connectionManager = ConnectionManager.shared
    @ObservedObject private var profileStore = UserProfileStore.shared
    
    @State private var searchQuery: String = ""
    @State private var selectedType: ConnectionRelationshipType = .partner
    @State private var searchResults: [DancerSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var selectedTarget: DancerSearchResult? = nil
    
    @State private var isSending: Bool = false
    @State private var successMessage: String? = nil
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 1. Relationship Type Picker (only partners until the coach tools are back)
                        if AppFeatures.coachTools {
                            relationshipTypeSection
                        }
                        
                        // 2. Search Input (Dancer ID or Name)
                        searchFieldSection
                        
                        // 3. Search Results
                        resultsSection
                        
                        // 4. Status Messages
                        if let success = successMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.syncEmerald)
                                Text(success)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(Color.syncEmerald.opacity(0.15))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.syncEmerald.opacity(0.3), lineWidth: 1))
                        }
                        
                        if let error = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.latinCrimson)
                                Text(error)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(Color.latinCrimson.opacity(0.15))
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.latinCrimson.opacity(0.3), lineWidth: 1))
                        }
                        
                        // 5. Send Request Button
                        if let target = selectedTarget {
                            sendRequestButton(for: target)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Nové prepojenie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zavrieť") {
                        dismiss()
                    }
                    .foregroundColor(LuxuryTheme.gold400)
                }
            }
        }
    }
    
    // MARK: - 1. Relationship Type Section
    private var relationshipTypeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TYP PREPOJENIA")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(LuxuryTheme.gold400)
                .tracking(1.2)
            
            HStack(spacing: 10) {
                typeButton(
                    type: .partner,
                    title: "Tanečný Partner",
                    icon: "figure.dance",
                    desc: "Obojsmerné zdieľanie choreografií"
                )
                
                typeButton(
                    type: .coachStudent,
                    title: profileStore.isCoach ? "Môj Zverenec" : "Môj Tréner",
                    icon: "graduationcap.fill",
                    desc: profileStore.isCoach ? "Tréningový manažment" : "Dohľad nad choreografiami"
                )
            }
        }
    }
    
    private func typeButton(type: ConnectionRelationshipType, title: String, icon: String, desc: String) -> some View {
        let isSelected = selectedType == type
        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedType = type
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isSelected ? LuxuryTheme.gold400 : .white.opacity(0.5))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(LuxuryTheme.gold400)
                    }
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text(desc)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .background(isSelected ? LuxuryTheme.obsidian800 : Color.white.opacity(0.04))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? LuxuryTheme.gold400 : Color.white.opacity(0.1), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 2. Search Field Section
    private var searchFieldSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("VYHĽADAŤ TANEČNÍKA")
                .font(.system(size: 11, weight: .black))
                .foregroundColor(LuxuryTheme.gold400)
                .tracking(1.2)
            
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(LuxuryTheme.gold400.opacity(0.7))
                
                TextField("", text: $searchQuery, prompt: Text("ID tanečníka (napr. DNC-8492) alebo meno").foregroundColor(Color.white.opacity(0.35)))
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .onChange(of: searchQuery) { _, newValue in
                        triggerSearch(query: newValue)
                    }
                
                if isSearching {
                    ProgressView().tint(LuxuryTheme.gold400).scaleEffect(0.8)
                } else if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchResults = []
                        selectedTarget = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
            .padding(14)
            .background(LuxuryTheme.obsidian800)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LuxuryTheme.gold500.opacity(0.25), lineWidth: 1))
        }
    }
    
    // MARK: - 3. Results Section
    private var resultsSection: some View {
        VStack(spacing: 8) {
            if searchResults.isEmpty && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && !isSearching {
                Text("Nikoho s týmto ID tanečníka ani menom sme nenašli.")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, 16)
            } else {
                ForEach(searchResults) { dancer in
                    let isSelected = selectedTarget?.id == dancer.id
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedTarget = dancer
                        }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LuxuryTheme.gold500.opacity(0.2))
                                    .frame(width: 42, height: 42)
                                Image(systemName: "person.fill")
                                    .foregroundColor(LuxuryTheme.gold400)
                            }
                            .overlay(Circle().stroke(LuxuryTheme.gold500.opacity(0.3), lineWidth: 1))
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(dancer.fullName)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 6) {
                                    Text(dancer.dancerCode)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(LuxuryTheme.gold300)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(LuxuryTheme.gold500.opacity(0.18))
                                        .cornerRadius(5)
                                    
                                    if !dancer.club.isEmpty {
                                        Text("• \(dancer.club)")
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.65))
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? LuxuryTheme.gold400 : .white.opacity(0.3))
                        }
                        .padding(14)
                        .background(isSelected ? LuxuryTheme.obsidian700 : Color.white.opacity(0.03))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? LuxuryTheme.gold400 : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - 5. Send Request Button
    private func sendRequestButton(for target: DancerSearchResult) -> some View {
        Button {
            executeSendRequest(target: target)
        } label: {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView().tint(LuxuryTheme.obsidian900)
                }
                Image(systemName: "paperplane.fill")
                Text(isSending ? "Odosielam..." : "Odoslať žiadosť o prepojenie")
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(LuxuryTheme.obsidian900)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                LinearGradient(
                    colors: [LuxuryTheme.gold500, LuxuryTheme.gold400],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: LuxuryTheme.gold500.opacity(0.35), radius: 10, y: 3)
        }
        .disabled(isSending)
    }
    
    // MARK: - Actions
    private func triggerSearch(query: String) {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else {
            searchResults = []
            return
        }
        isSearching = true
        errorMessage = nil
        
        Task {
            let res = await connectionManager.searchDancers(query: clean)
            await MainActor.run {
                self.searchResults = res
                self.isSearching = false
                if let first = res.first, clean.uppercased() == first.dancerCode.uppercased() {
                    self.selectedTarget = first
                }
            }
        }
    }
    
    private func executeSendRequest(target: DancerSearchResult) {
        isSending = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                try await connectionManager.sendRequest(targetUserId: target.id, type: selectedType)
                await MainActor.run {
                    self.isSending = false
                    self.successMessage = "Žiadosť pre tanečníka \(target.fullName) bola úspešne odoslaná!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSending = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Xcode Canvas Preview
#Preview("AddConnectionSheetView - Nové Prepojenie") {
    AddConnectionSheetView()
        .previewWithSampleData()
}
