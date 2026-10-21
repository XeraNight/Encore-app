import SwiftUI
import Foundation

// Helper struct for navigationDestination
struct IdentifiableRoutineItem: Identifiable, Hashable {
    let student: DancerConnection
    let routine: DBRoutineRow

    var id: UUID { routine.id }

    static func == (lhs: IdentifiableRoutineItem, rhs: IdentifiableRoutineItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Moji zverenci
/// The coach's students: their routines and, per student, what the last lesson was about (Premium).
/// "Trainer" is a role from the connection, not from the plan (BRAND_GUIDELINES §1A).
struct StudioCoachRosterView: View {
    @ObservedObject private var connectionManager = ConnectionManager.shared
    @ObservedObject private var studioManager = StudioManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var searchQuery = ""
    @State private var showAddStudentSheet = false
    @State private var selectedRoutineItem: IdentifiableRoutineItem?
    @State private var lessonStudent: DancerConnection?
    @State private var showPaywall = false

    private var canWriteLessons: Bool { subscriptionManager.currentTier >= .premium }

    private var filteredStudents: [DancerConnection] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return connectionManager.activeStudents }
        return connectionManager.activeStudents.filter {
            $0.otherUserName.localizedCaseInsensitiveContains(query)
                || $0.otherUserClub.localizedCaseInsensitiveContains(query)
                || $0.otherUserDancerCode.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            EllegancePageBackground()

            if connectionManager.activeStudents.isEmpty {
                emptyRoster
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        searchField
                        ForEach(filteredStudents) { student in
                            studentCard(student)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable { await refreshAll() }
            }
        }
        .navigationTitle("Moji zverenci")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddStudentSheet = true
                } label: {
                    Label("Pridať", systemImage: "person.badge.plus")
                        .foregroundColor(Color.gold400)
                }
            }
        }
        .sheet(isPresented: $showAddStudentSheet) { AddConnectionSheetView() }
        .sheet(item: $lessonStudent) { student in
            CoachLessonSheet(student: student)
        }
        .sheet(isPresented: $showPaywall) { SubscriptionPaywallView(initialTier: .premium) }
        .navigationDestination(item: $selectedRoutineItem) { item in
            StudentRoutineDetailView(
                studentId: item.student.otherUserId,
                studentName: item.student.otherUserName,
                routine: item.routine
            )
        }
        .task { await refreshAll() }
        .preferredColorScheme(.dark)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.gold400)
            TextField("", text: $searchQuery, prompt: Text("Meno, klub alebo ID tanečníka").foregroundColor(.white.opacity(0.4)))
                .foregroundColor(.white)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .homeCard(cornerRadius: 14)
    }

    // MARK: Student
    private func studentCard(_ student: DancerConnection) -> some View {
        let routines = studioManager.studentRoutines[student.otherUserId] ?? []
        let lastLesson = studioManager.lastLessons[student.otherUserId]

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(student.otherUserName.prefix(2).uppercased())
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .foregroundColor(Color.obsidian900)
                    .frame(width: 44, height: 44)
                    .background(LinearGradient(colors: [Color.gold500, Color.gold300], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(student.otherUserName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text([student.otherUserClub, student.otherUserDancerCode].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                }
                Spacer()
                Text(slovakRoutineCount(routines.count))
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color.gold300)
            }

            lastLessonRow(student, lesson: lastLesson)

            if routines.isEmpty {
                Text("Zatiaľ nemá žiadnu zostavu.")
                    .font(.footnote)
                    .foregroundColor(Color.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(routines, id: \.id) { routine in
                        Button {
                            selectedRoutineItem = IdentifiableRoutineItem(student: student, routine: routine)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "figure.dance")
                                    .foregroundColor(Color.gold400)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(routine.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white)
                                    Text([routine.dance_name, routine.last_modified_by ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundColor(Color.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressable(scale: 0.98))
                        if routine.id != routines.last?.id { HomeRowDivider() }
                    }
                }
            }
        }
        .padding(16)
        .homeCard(cornerRadius: 20)
    }

    private func lastLessonRow(_ student: DancerConnection, lesson: CoachLesson?) -> some View {
        Button {
            if canWriteLessons { lessonStudent = student } else { showPaywall = true }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: canWriteLessons ? "clock.arrow.circlepath" : "lock.fill")
                    .foregroundColor(Color.gold400)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.map { "NAPOSLEDY · \($0.dayText.uppercased())" } ?? "ČO STE ROBILI NAPOSLEDY")
                        .font(.system(.caption2, design: .rounded).weight(.black))
                        .tracking(1)
                        .foregroundColor(Color.gold400)
                    Text(lesson?.summary ?? (canWriteLessons ? "Po lekcii si zapíš, čo ste robili. Nabudúce to uvidíš tu." : "Zápis lekcií je v Premium."))
                        .font(.footnote)
                        .foregroundColor(.white.opacity(lesson == nil ? 0.6 : 0.9))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Color.gold400)
            }
            .padding(12)
            .background(Color.gold500.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.pressable(scale: 0.98))
        .accessibilityHint("Zapísať lekciu a pozrieť predošlé")
    }

    private var emptyRoster: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 34))
                .foregroundColor(Color.gold400)
                .frame(width: 76, height: 76)
                .glassEffect(.regular, in: .circle)
            Text("Zatiaľ žiadni zverenci")
                .font(.headline)
                .foregroundColor(.white)
            Text("Pridaj zverenca cez jeho ID tanečníka. Uvidíš jeho zostavy a môžeš mu pridávať figúry a poznámky.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            PrimarySheetButton(title: "Pridať zverenca", isLoading: false, isEnabled: true) {
                showAddStudentSheet = true
            }
            .padding(.horizontal, 48)
        }
    }

    private func slovakRoutineCount(_ count: Int) -> String {
        switch count {
        case 1: return "1 zostava"
        case 2...4: return "\(count) zostavy"
        default: return "\(count) zostáv"
        }
    }

    private func refreshAll() async {
        await connectionManager.fetchAllConnections()
        await studioManager.fetchLastLessons()
        for student in connectionManager.activeStudents {
            _ = await studioManager.fetchStudentRoutines(studentUserId: student.otherUserId)
        }
    }
}

// MARK: - Lesson log for one student
/// Write what the lesson was about; earlier lessons below. Only the coach sees them.
struct CoachLessonSheet: View {
    let student: DancerConnection

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var studioManager = StudioManager.shared

    @State private var date = Date()
    @State private var summary = ""
    @State private var history: [CoachLesson] = []
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var successTick = 0

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            HomeSectionHeader(title: "DNEŠNÁ LEKCIA", systemImage: "square.and.pencil")
                            DatePicker("Dátum", selection: $date, in: ...Date(), displayedComponents: .date)
                                .environment(\.locale, Locale(identifier: "sk"))
                                .tint(Color.gold400)
                                .foregroundColor(.white)
                            TextField("", text: $summary,
                                      prompt: Text("Napríklad: waltz natural turn, hlava doľava; tango promenáda").foregroundColor(.white.opacity(0.4)),
                                      axis: .vertical)
                                .lineLimit(3...8)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            PrimarySheetButton(title: "Uložiť lekciu", isLoading: isSaving,
                                               isEnabled: !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                               action: save)
                            Text("Vidíš to len ty, \(student.otherUserName) nie.")
                                .font(.caption)
                                .foregroundColor(Color.textSecondary)
                        }
                        .padding(16)
                        .homeCard(cornerRadius: 20)

                        if !history.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HomeSectionHeader(title: "PREDOŠLÉ LEKCIE", systemImage: "clock.arrow.circlepath", count: history.count)
                                ForEach(history) { lesson in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(lesson.dayText)
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(Color.gold300)
                                        Text(lesson.summary)
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .homeCard(cornerRadius: 14)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            delete(lesson)
                                        } label: {
                                            Label("Odstrániť", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(student.otherUserName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavrieť") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
            }
            .alert("Nepodarilo sa", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
            .sensoryFeedback(.success, trigger: successTick)
            .task { await loadHistory() }
        }
        .preferredColorScheme(.dark)
    }

    private func loadHistory() async {
        history = (try? await studioManager.lessons(for: student.otherUserId)) ?? []
    }

    private func save() {
        let text = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await studioManager.addLesson(studentId: student.otherUserId, date: date, summary: text)
                summary = ""
                successTick += 1
                await loadHistory()
            } catch {
                errorText = "Lekciu sa nepodarilo uložiť. Zápis lekcií je v Premium a zverenec musí byť prepojený."
            }
        }
    }

    private func delete(_ lesson: CoachLesson) {
        Task {
            do {
                try await studioManager.deleteLesson(lesson)
                await loadHistory()
            } catch {
                errorText = "Lekciu sa nepodarilo odstrániť."
            }
        }
    }
}

#Preview("Moji zverenci") {
    NavigationStack {
        StudioCoachRosterView()
    }
    .previewWithSampleData()
}
