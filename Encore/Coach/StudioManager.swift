import Foundation
import SwiftUI
import Combine
import Supabase
import OSLog

// MARK: - Studio & Coach Management Service
@MainActor
final class StudioManager: ObservableObject {
    static let shared = StudioManager()
    
    @Published var studentRoutines: [UUID: [DBRoutineRow]] = [:]
    @Published var routineNodes: [UUID: [DBCanvasNodeRow]] = [:]
    /// The newest lesson per student, for "Naposledy" on the roster (Premium).
    @Published var lastLessons: [UUID: CoachLesson] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Clear caches when user logs out
        AuthManager.shared.$currentUser
            .receive(on: RunLoop.main)
            .sink { [weak self] user in
                if user == nil {
                    self?.reset()
                }
            }
            .store(in: &cancellables)
    }
    
    func reset() {
        studentRoutines = [:]
        routineNodes = [:]
        lastLessons = [:]
        isLoading = false
        errorMessage = nil
    }
    
    // MARK: - Fetch Student Routines (Supabase RLS Protected)
    func fetchStudentRoutines(studentUserId: UUID) async -> [DBRoutineRow] {
        let client = SupabaseConfig.client
        isLoading = true
        defer { isLoading = false }
        
        do {
            let rows: [DBRoutineRow] = try await client
                .from("routines")
                .select()
                .eq("user_id", value: studentUserId)
                .order("updated_at", ascending: false)
                .execute()
                .value
            
            self.studentRoutines[studentUserId] = rows
            return rows
        } catch {
            Logger.sync.error("fetchStudentRoutines failed: \(error.localizedDescription, privacy: .public)")
            self.errorMessage = error.localizedDescription
            return []
        }
    }
    
    // MARK: - Fetch Canvas Nodes for Routine
    func fetchRoutineNodes(routineId: UUID) async -> [DBCanvasNodeRow] {
        let client = SupabaseConfig.client
        
        do {
            let nodes: [DBCanvasNodeRow] = try await client
                .from("canvas_nodes")
                .select()
                .eq("routine_id", value: routineId)
                .order("order_index", ascending: true)
                .execute()
                .value
            
            self.routineNodes[routineId] = nodes
            return nodes
        } catch {
            Logger.sync.error("fetchRoutineNodes failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
    
    // MARK: - Assign Figure From Coach Library to Student Routine
    func assignFigureToStudentRoutine(
        routineId: UUID,
        figureName: String,
        rhythm: String,
        coachNotes: String,
        transitionNotes: String = "Priradené trénerom"
    ) async throws {
        let client = SupabaseConfig.client
        
        // 1. Fetch current nodes to calculate next orderIndex & positioning
        var currentNodes = routineNodes[routineId] ?? []
        if currentNodes.isEmpty {
            currentNodes = await fetchRoutineNodes(routineId: routineId)
        }
        let nextIndex = (currentNodes.map(\.order_index).max() ?? -1) + 1
        
        // Compute smart ballroom floor coordinates (e.g., stagger on dance floor)
        let lastNode = currentNodes.last
        let nextX = lastNode != nil ? min(lastNode!.x + 120, 780) : 160.0
        let nextY = lastNode != nil ? min(lastNode!.y + 100, 1100) : 180.0
        
        let newNode = DBCanvasNodeRow(
            id: UUID(),
            routine_id: routineId,
            x: nextX,
            y: nextY,
            figure_name: figureName,
            rhythm: rhythm,
            notes: "",
            video_path: nil,
            order_index: nextIndex,
            transition_notes: transitionNotes
        )
        
        // 2. Insert into canvas_nodes
        try await client
            .from("canvas_nodes")
            .insert(newNode)
            .execute()

        // The coach's remark goes into its own field; the student's notes stay the student's.
        let trimmedRemark = coachNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRemark.isEmpty {
            struct CoachNoteDTO: Encodable { let coach_notes: String }
            try await client
                .from("canvas_nodes")
                .update(CoachNoteDTO(coach_notes: trimmedRemark))
                .eq("id", value: newNode.id)
                .execute()
        }
        
        // 3. Mark routine with Coach signature in last_modified_by
        let coachName = UserProfileStore.shared.currentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let signature = coachName.isEmpty || coachName == "Tanečník" ? "Tréner" : "\(coachName) (Tréner)"
        
        struct RoutineUpdateDTO: Encodable {
            let last_modified_by: String
            let updated_at: String
        }
        
        let nowISO = ISO8601DateFormatter().string(from: Date())
        try await client
            .from("routines")
            .update(RoutineUpdateDTO(last_modified_by: signature, updated_at: nowISO))
            .eq("id", value: routineId)
            .execute()
        
        // 4. Update local cache
        var updatedList = currentNodes
        updatedList.append(newNode)
        self.routineNodes[routineId] = updatedList
        
        // Update cached routine record
        for (studentId, list) in studentRoutines {
            if let idx = list.firstIndex(where: { $0.id == routineId }) {
                let old = list[idx]
                let updated = DBRoutineRow(
                    id: old.id,
                    name: old.name,
                    dance_name: old.dance_name,
                    dance_category: old.dance_category,
                    created_at: old.created_at,
                    updated_at: Date(),
                    last_modified_by: signature
                )
                var mutableList = list
                mutableList[idx] = updated
                self.studentRoutines[studentId] = mutableList
            }
        }
    }
    
    // MARK: - Update Node Coach Notes
    func updateNodeNotes(
        routineId: UUID,
        nodeId: UUID,
        coachNotes: String
    ) async throws {
        let client = SupabaseConfig.client
        
        struct NodeUpdateDTO: Encodable {
            let coach_notes: String
        }
        
        try await client
            .from("canvas_nodes")
            .update(NodeUpdateDTO(coach_notes: coachNotes))
            .eq("id", value: nodeId)
            .execute()
        
        let coachName = UserProfileStore.shared.currentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let signature = coachName.isEmpty || coachName == "Tanečník" ? "Tréner" : "\(coachName) (Tréner)"
        
        struct RoutineUpdateDTO: Encodable {
            let last_modified_by: String
            let updated_at: String
        }
        
        let nowISO = ISO8601DateFormatter().string(from: Date())
        try await client
            .from("routines")
            .update(RoutineUpdateDTO(last_modified_by: signature, updated_at: nowISO))
            .eq("id", value: routineId)
            .execute()
        
        // Refresh local cache
        _ = await fetchRoutineNodes(routineId: routineId)
    }

    // MARK: - "Čo sme robili naposledy" (Premium; only the coach sees it)
    /// Newest lesson per student. Reading works on every plan; writing is Premium (the server checks too).
    func fetchLastLessons() async {
        do {
            let rows: [CoachLesson] = try await SupabaseConfig.client
                .from("coach_lessons")
                .select("id, student_id, lesson_date, summary, created_at")
                .order("lesson_date", ascending: false)
                .order("created_at", ascending: false)
                .limit(500)
                .execute()
                .value
            var newest: [UUID: CoachLesson] = [:]
            for lesson in rows where newest[lesson.studentId] == nil {
                newest[lesson.studentId] = lesson
            }
            lastLessons = newest
        } catch {
            Logger.sync.error("fetchLastLessons failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func lessons(for studentId: UUID) async throws -> [CoachLesson] {
        try await SupabaseConfig.client
            .from("coach_lessons")
            .select("id, student_id, lesson_date, summary, created_at")
            .eq("student_id", value: studentId)
            .order("lesson_date", ascending: false)
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value
    }

    func addLesson(studentId: UUID, date: Date, summary: String) async throws {
        struct Row: Encodable { let student_id: UUID; let lesson_date: String; let summary: String }
        try await SupabaseConfig.client
            .from("coach_lessons")
            .insert(Row(student_id: studentId, lesson_date: CoachLesson.dayString(date), summary: summary))
            .execute()
        await fetchLastLessons()
    }

    func deleteLesson(_ lesson: CoachLesson) async throws {
        try await SupabaseConfig.client.from("coach_lessons").delete().eq("id", value: lesson.id).execute()
        await fetchLastLessons()
    }
}

/// One lesson summary a coach wrote for a student (`coach_lessons`).
struct CoachLesson: Identifiable, Decodable, Sendable, Equatable {
    let id: UUID
    let studentId: UUID
    /// yyyy-MM-dd
    let lessonDate: String
    let summary: String

    enum CodingKeys: String, CodingKey {
        case id
        case studentId = "student_id"
        case lessonDate = "lesson_date"
        case summary
    }

    private static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayString(_ date: Date) -> String { isoDay.string(from: date) }

    /// "dnes", "včera", "7. okt."
    var dayText: String {
        guard let date = Self.isoDay.date(from: lessonDate) else { return lessonDate }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "dnes" }
        if calendar.isDateInYesterday(date) { return "včera" }
        return date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "sk")))
    }
}
