import SwiftUI

// MARK: - Add Dancer Connection Sheet (Search by Dancer ID or Name)
/// BRAND_GUIDELINES §1A: velvet, glass cards, shared field, banner and primary button.
struct AddConnectionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var connectionManager = ConnectionManager.shared
    @ObservedObject private var profileStore = UserProfileStore.shared

    @State private var searchQuery: String = ""
    @State private var selectedType: ConnectionRelationshipType = .connection
    @State private var searchResults: [DancerSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>?
    @State private var selectedTarget: DancerSearchResult? = nil
    @FocusState private var isSearchFocused: Bool

    @State private var isSending: Bool = false
    @State private var successMessage: String? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Only plain connections until the coach tools are back; the partner is chosen later
                        // from the connections.
                        if AppFeatures.coachTools {
                            relationshipTypeSection
                        }
                        searchFieldSection
                        resultsSection

                        if let success = successMessage {
                            SheetBanner(text: success, isError: false)
                        }
                        if let error = errorMessage {
                            SheetBanner(text: error, isError: true)
                        }
                        if let target = selectedTarget {
                            PrimarySheetButton(title: "Poslať žiadosť o spojenie", isLoading: isSending, isEnabled: successMessage == nil) {
                                executeSendRequest(target: target)
                            }
                            .accessibilityIdentifier("connection.send")
                            .transition(.scale(scale: 0.96).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTarget)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: successMessage)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: errorMessage)
                }
            }
            .navigationTitle("Nové spojenie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zavrieť") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
            }
            .sensoryFeedback(.selection, trigger: selectedType)
            .sensoryFeedback(.selection, trigger: selectedTarget)
            .sensoryFeedback(.success, trigger: successMessage) { _, new in new != nil }
            .sensoryFeedback(.error, trigger: errorMessage) { _, new in new != nil }
        }
    }

    // MARK: - Relationship type
    private var relationshipTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "TYP PREPOJENIA", systemImage: "link")
            HStack(spacing: 10) {
                typeButton(type: .connection, title: "Spojenie", icon: "person.2.fill",
                           desc: "Bez prístupu k tvojim zostavám")
                typeButton(type: .coachStudent,
                           title: profileStore.isCoach ? "Môj zverenec" : "Môj tréner",
                           icon: "graduationcap.fill",
                           desc: profileStore.isCoach ? "Tréningový manažment" : "Dohľad nad choreografiami")
            }
        }
    }

    private func typeButton(type: ConnectionRelationshipType, title: String, icon: String, desc: String) -> some View {
        let isSelected = selectedType == type
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedType = type }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .font(.callout.weight(.bold))
                        .foregroundColor(isSelected ? Color.gold400 : .white.opacity(0.6))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundColor(Color.gold400)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .homeCard(cornerRadius: 14)
            .overlay(selectionStroke(isSelected, cornerRadius: 14))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Search field
    private var searchFieldSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "VYHĽADAŤ TANEČNÍKA", systemImage: "magnifyingglass")
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.gold400.opacity(0.8))
                TextField("", text: $searchQuery,
                          prompt: Text("ID tanečníka (napr. DNC-8492) alebo meno").foregroundColor(.white.opacity(0.5)))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .onChange(of: searchQuery) { _, newValue in
                        triggerSearch(query: newValue)
                    }
                if isSearching {
                    ProgressView().tint(Color.gold400).scaleEffect(0.8)
                } else if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchResults = []
                        selectedTarget = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Vymazať hľadanie")
                    .padding(.vertical, -12)
                }
            }
            .authFieldChrome(isFocused: isSearchFocused)
        }
    }

    // MARK: - Results
    private var resultsSection: some View {
        VStack(spacing: 8) {
            if searchResults.isEmpty && searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 && !isSearching {
                Text("Nikoho s týmto ID tanečníka ani menom sme nenašli.")
                    .font(.footnote)
                    .foregroundColor(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ForEach(searchResults) { dancer in
                    resultRow(dancer)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: searchResults)
    }

    private func resultRow(_ dancer: DancerSearchResult) -> some View {
        let isSelected = selectedTarget?.id == dancer.id
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedTarget = dancer }
        } label: {
            HStack(spacing: 12) {
                ProfileAvatarView(name: dancer.fullName, imagePath: nil, avatarURL: dancer.avatarUrl, size: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(dancer.fullName)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                    HStack(spacing: 6) {
                        Text(dancer.dancerCode)
                            .font(.caption2.weight(.bold).monospaced())
                            .foregroundColor(Color.gold300)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gold500.opacity(0.18), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        if !dancer.club.isEmpty {
                            Text(dancer.club)
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? Color.gold400 : .white.opacity(0.4))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(14)
            .homeCard(cornerRadius: 14)
            .overlay(selectionStroke(isSelected, cornerRadius: 14))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectionStroke(_ isSelected: Bool, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(Color.gold400.opacity(isSelected ? 0.8 : 0), lineWidth: 1.5)
    }

    // MARK: - Actions
    /// One request once typing pauses, not one per letter (each costs a server call and counts toward the
    /// search limit); an older answer arriving late never replaces a newer one.
    private func triggerSearch(query: String) {
        searchTask?.cancel()
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        errorMessage = nil
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let res = await connectionManager.searchDancers(query: clean)
            guard !Task.isCancelled else { return }
            searchResults = res
            isSearching = false
            if let first = res.first, clean.uppercased() == first.dancerCode.uppercased() {
                selectedTarget = first
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
                isSending = false
                successMessage = "Žiadosť pre \(target.fullName) je odoslaná. Keď ju potvrdí, budete spojení."
                try? await Task.sleep(for: .seconds(1.6))
                dismiss()
            } catch {
                isSending = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Xcode Canvas Preview
#Preview("AddConnectionSheetView - Nové spojenie") {
    AddConnectionSheetView()
        .previewWithSampleData()
}
