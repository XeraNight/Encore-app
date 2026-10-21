import Foundation
import SwiftData
import SwiftUI

enum VideoMediaRole: String, Codable, CaseIterable, Identifiable {
    case myTake = "my_take"
    case targetIdol = "target_idol"
    case coach = "coach"
    case draft = "draft"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .myTake: return "Moje video"
        case .targetIdol: return "Vzor"
        case .coach: return "Od trénera"
        case .draft: return "Návrh"
        }
    }
    
    var iconName: String {
        switch self {
        case .myTake: return "person.fill"
        case .targetIdol: return "star.fill"
        case .coach: return "person.badge.shield.checkmark.fill"
        case .draft: return "lightbulb.fill"
        }
    }
    
    /// Icon tint on the dark glass badge (brand colours, no traffic-light red and green).
    var tagColor: Color {
        switch self {
        case .myTake: return .white
        case .targetIdol: return Color.gold400
        case .coach: return Color.gold300
        case .draft: return Color.white.opacity(0.7)
        }
    }
}

@Model
final class VideoMediaEntry {
    @Attribute(.unique) var id: UUID
    var filePath: String
    var title: String
    var roleRawValue: String
    var createdAt: Date
    var isFavorite: Bool
    
    var routine: Routine?
    var canvasNode: CanvasNode?
    
    var role: VideoMediaRole {
        get { VideoMediaRole(rawValue: roleRawValue) ?? .myTake }
        set { roleRawValue = newValue.rawValue }
    }
    
    init(id: UUID = UUID(), filePath: String, title: String, role: VideoMediaRole = .myTake, createdAt: Date = Date(), isFavorite: Bool = false) {
        self.id = id
        self.filePath = filePath
        self.title = title
        self.roleRawValue = role.rawValue
        self.createdAt = createdAt
        self.isFavorite = isFavorite
    }
}

@Model
final class Dance {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String // "Standard" or "Latin"
    var tempo: String
    var info: String
    var imagePath: String?
    var videoPath: String?
    
    init(id: UUID = UUID(), name: String, category: String, tempo: String, info: String, imagePath: String? = nil, videoPath: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.tempo = tempo
        self.info = info
        self.imagePath = imagePath
        self.videoPath = videoPath
    }
}

@Model
final class FigureLibraryItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var danceName: String
    var rhythm: String
    var techniqueNotes: String
    var imagePath: String?
    var videoPath: String?
    var isCustom: Bool
    var masteryRating: Int = 3 // 1 to 5 stars
    
    init(id: UUID = UUID(), name: String, danceName: String, rhythm: String, techniqueNotes: String = "", imagePath: String? = nil, videoPath: String? = nil, isCustom: Bool = false, masteryRating: Int = 3) {
        self.id = id
        self.name = name
        self.danceName = danceName
        self.rhythm = rhythm
        self.techniqueNotes = techniqueNotes
        self.imagePath = imagePath
        self.videoPath = videoPath
        self.isCustom = isCustom
        self.masteryRating = masteryRating
    }
}

@Model
final class Routine {
    @Attribute(.unique) var id: UUID
    var name: String
    var danceName: String
    var danceCategory: String // "Standard" or "Latin"
    var createdAt: Date
    var updatedAt: Date
    var lastModifiedBy: String?
    var videoPath: String?
    var activeTargetVideoPath: String?
    /// The drawing on the floor (`CanvasSketch`), kept on this iPhone only; it is not part of the sync.
    @Attribute(.externalStorage) var sketchData: Data? = nil
    
    @Relationship(deleteRule: .cascade, inverse: \CanvasNode.routine)
    var canvasNodes: [CanvasNode] = []
    
    @Relationship(deleteRule: .cascade, inverse: \VideoMediaEntry.routine)
    var mediaVault: [VideoMediaEntry] = []
    
    init(id: UUID = UUID(), name: String, danceName: String, danceCategory: String, createdAt: Date = Date(), updatedAt: Date = Date(), lastModifiedBy: String? = nil, videoPath: String? = nil, activeTargetVideoPath: String? = nil) {
        self.id = id
        self.name = name
        self.danceName = danceName
        self.danceCategory = danceCategory
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastModifiedBy = lastModifiedBy
        self.videoPath = videoPath
        self.activeTargetVideoPath = activeTargetVideoPath
    }
}

extension Routine {
    var isLatin: Bool {
        let category = danceCategory.lowercased()
        return category == "latin" || category == "latina"
    }
}

@Model
final class CanvasNode {
    @Attribute(.unique) var id: UUID
    var x: Double
    var y: Double
    var figureName: String
    var rhythm: String
    var notes: String
    /// The original video on this iPhone: a Fotky link (`photos:`) or a file in the app. Never synced,
    /// because it only works on this device. Partner and coach see `sharedVideoPath` instead.
    var videoPath: String?
    var activeTargetVideoPath: String? // Active Target/Idol video
    var orderIndex: Int
    var transitionNotes: String
    var masteryRating: Int = 3 // 1 to 5 stars
    /// Formatted version of `notes` (AttributedString as JSON). Local only. `notes` stays the plain
    /// text mirror that sync, QR and the coach use; the formatting is dropped when they differ.
    var notesRichData: Data? = nil
    /// Quarter turns of the figure video, like rotating in Photos: 0, 90, 180 or 270 degrees (local only).
    var videoRotation: Int? = nil
    /// Note from the student's coach. Read-only for the dancer; the server decides who may write it.
    var coachNotes: String? = nil
    var coachNotesAuthor: String? = nil
    var coachNotesAt: Date? = nil
    /// The copy shared with partner and coach (`canvas_nodes.video_path` on the server).
    var sharedVideoPath: String? = nil
    /// How many bars the figure is danced in this routine; with the dance's tempo it gives the figure's and the
    /// routine's length (`RoutineTiming`). Stays on this iPhone until `canvas_nodes.bars` exists on the server.
    var bars: Int? = nil

    /// What the figure shows: the own original first, otherwise the shared copy.
    var displayVideoPath: String? { videoPath ?? sharedVideoPath }

    var routine: Routine?
    
    @Relationship(deleteRule: .cascade, inverse: \VideoMediaEntry.canvasNode)
    var mediaVault: [VideoMediaEntry] = []
    
    init(id: UUID = UUID(), x: Double, y: Double, figureName: String, rhythm: String = "", notes: String = "", videoPath: String? = nil, activeTargetVideoPath: String? = nil, orderIndex: Int = 0, transitionNotes: String = "", masteryRating: Int = 3) {
        self.id = id
        self.x = x
        self.y = y
        self.figureName = figureName
        self.rhythm = rhythm
        self.notes = notes
        self.videoPath = videoPath
        self.activeTargetVideoPath = activeTargetVideoPath
        self.orderIndex = orderIndex
        self.transitionNotes = transitionNotes
        self.masteryRating = masteryRating
    }
}

// MARK: - Figures Database Seeding Extension
extension FigureLibraryItem {
    static func seedDefaultFigures(in context: ModelContext) {
        let figuresData: [String: [(String, String)]] = [
            "Waltz": [
                ("Closed Changes", "1, 2, 3"),
                ("Natural Turn", "1, 2, 3"),
                ("Reverse Turn", "1, 2, 3"),
                ("Whisk", "1, 2, 3"),
                ("Chasse from PP", "1, 2 a 3"),
                ("Natural Spin Turn", "1, 2, 3, 4, 5, 6"),
                ("Reverse Corte", "1, 2, 3"),
                ("Outside Spin", "1, 2, 3"),
                ("Double Reverse Spin", "1, 2, a3"),
                ("Weave from PP", "1, 2, 3, 4, 5, 6")
            ],
            "Tango": [
                ("Progressive Side Step", "Quick, Quick"),
                ("Rock Turn", "Slow, Quick, Quick, Slow"),
                ("Open Promenade", "Slow, Quick, Quick, Slow"),
                ("Back Corte", "Slow, Quick, Quick, Slow"),
                ("Progressive Link", "Quick, Quick"),
                ("Closed Promenade", "Slow, Quick, Quick, Slow"),
                ("Four Step", "Quick, Quick, Quick, Quick"),
                ("Fallaway Promenade", "Slow, Quick, Quick, Slow"),
                ("Outside Swivel", "Slow, Quick"),
                ("Five Step", "Quick, Quick, Quick, Quick, Slow")
            ],
            "Viennese Waltz": [
                ("Natural Turn", "1, 2, 3"),
                ("Reverse Turn", "1, 2, 3"),
                ("Forward Change (Nat to Rev)", "1, 2, 3"),
                ("Forward Change (Rev to Nat)", "1, 2, 3"),
                ("Backward Change (Nat to Rev)", "1, 2, 3"),
                ("Backward Change (Rev to Nat)", "1, 2, 3"),
                ("Reverse Fleckerl", "1, 2, 3"),
                ("Contra Check", "1, 2, 3"),
                ("Natural Fleckerl", "1, 2, 3"),
                ("Left Foot Closed Change", "1, 2, 3")
            ],
            "Slowfoxtrot": [
                ("Feather Step", "Slow, Quick, Quick"),
                ("Three Step", "Slow, Quick, Quick"),
                ("Natural Turn", "Slow, Quick, Quick"),
                ("Reverse Turn so zakončením Feather Finish", "Slow, Quick, Quick, Slow, Quick, Quick"),
                ("Closed Impetus", "Slow, Quick, Quick"),
                ("Change of Direction", "Slow, Slow"),
                ("Open Telemark", "Slow, Quick, Quick"),
                ("Hover Feather", "Slow, Quick, Quick"),
                ("Natural Weave", "Slow, Quick, Quick, Quick, Quick, Quick, Quick"),
                ("Reverse Wave", "Slow, Quick, Quick, Slow, Quick, Quick")
            ],
            "Quickstep": [
                ("Quarter Turn to Right", "Slow, Quick, Quick, Slow"),
                ("Progressive Chasse", "Slow, Quick, Quick, Slow"),
                ("Forward Lock Step", "Slow, Quick, Quick, Slow"),
                ("Backward Lock Step", "Slow, Quick, Quick, Slow"),
                ("Natural Spin Turn", "Slow, Quick, Quick, Slow, Slow, Slow"),
                ("Chasse Reverse Turn", "Slow, Quick, Quick, Slow"),
                ("Change of Direction", "Slow, Slow"),
                ("Double Reverse Spin", "Slow, Slow, a-Slow"),
                ("Zig-Zag", "Slow, Slow, Quick, Quick, Slow"),
                ("Running Right Turn", "Slow, Quick, Quick, Slow, Slow, Slow, Quick, Quick, Slow")
            ],
            "Samba": [
                ("Basic Steps (Natural & Reverse)", "1 a 2"),
                ("Samba Whisks", "1 a 2"),
                ("Samba Walks in Promenade", "1 a 2"),
                ("Stationary Samba Walks", "1 a 2"),
                ("Bota Fogos", "1 a 2"),
                ("Voltas", "1 a 2 a 3 a 4"),
                ("Shadow Bota Fogos", "1 a 2"),
                ("Cortaca", "1 a 2 a 3 a 4"),
                ("Closed Rocks", "1 a 2"),
                ("Cruzados Walks", "1 a 2")
            ],
            "Cha-Cha-Cha": [
                ("Basic Movement (Closed & Open)", "2, 3, 4 a 1"),
                ("New York", "2, 3, 4 a 1"),
                ("Spot Turns", "2, 3, 4 a 1"),
                ("Hand to Hand", "2, 3, 4 a 1"),
                ("Three Cha-Chas", "2, 3, 4 a 1, 2, 3, 4 a 1"),
                ("Underarm Turns", "2, 3, 4 a 1"),
                ("Shoulder to Shoulder", "2, 3, 4 a 1"),
                ("Hockey Stick", "2, 3, 4 a 1"),
                ("Alemana", "2, 3, 4 a 1"),
                ("Natural Top", "2, 3, 4 a 1")
            ],
            "Rumba": [
                ("Basic Movement", "2, 3, 4, 1"),
                ("New York", "2, 3, 4, 1"),
                ("Spot Turns", "2, 3, 4, 1"),
                ("Hand to Hand", "2, 3, 4, 1"),
                ("Underarm Turns", "2, 3, 4, 1"),
                ("Cucaracha", "2, 3, 4, 1"),
                ("Shoulder to Shoulder", "2, 3, 4, 1"),
                ("Hockey Stick", "2, 3, 4, 1"),
                ("Alemana", "2, 3, 4, 1"),
                ("Opening Out to Right and Left", "2, 3, 4, 1")
            ],
            "Paso Doble": [
                ("Basic Movement", "1, 2, 3, 4, 5, 6, 7, 8"),
                ("Sur Place", "1, 2, 3, 4, 5, 6, 7, 8"),
                ("Chasses to Right and Left", "1, 2, 3, 4, 5, 6, 7, 8"),
                ("Promenade Link", "1, 2, 3, 4, 5, 6, 7, 8"),
                ("Deplacement", "1, 2, 3, 4, 5, 6, 7, 8"),
                ("Ecart", "1, 2, 3, 4, 5, 6, 7, 8"),
                ("Separation", "1, 2, 3, 4, 5, 6, 7, 8"),
                ("Fallaway Reverse Turn", "1, 2, 3, 4, 5, 6, 7, 8"),
                ("Huit", "1, 2, 3, 4, 5, 6, 7, 8"),
                ("La Passe", "1, 2, 3, 4, 5, 6, 7, 8")
            ],
            "Jive": [
                ("Basic In Place", "1, 2, 3 a 4, 5 a 6"),
                ("Fallaway Rock", "1, 2, 3 a 4, 5 a 6"),
                ("Change of Places Right to Left", "1, 2, 3 a 4, 5 a 6"),
                ("Change of Places Left to Right", "1, 2, 3 a 4, 5 a 6"),
                ("Link", "1, 2, 3 a 4, 5 a 6"),
                ("American Spin", "1, 2, 3 a 4, 5 a 6"),
                ("Stop and Go", "1, 2, 3 a 4, 5 a 6"),
                ("Mooch", "1, 2, 3 a 4, 5 a 6"),
                ("Whip", "1, 2, 3 a 4, 5 a 6"),
                ("Windmill", "1, 2, 3 a 4, 5 a 6")
            ]
        ]
        
        let existingFigures = (try? context.fetch(FetchDescriptor<FigureLibraryItem>())) ?? []
        var existingSet = Set<String>(minimumCapacity: existingFigures.count)
        for fig in existingFigures {
            existingSet.insert("\(fig.danceName)_\(fig.name)")
        }
        
        for (danceName, figures) in figuresData {
            for fig in figures {
                let key = "\(danceName)_\(fig.0)"
                if existingSet.contains(key) {
                    continue
                }
                
                let item = FigureLibraryItem(
                    name: fig.0,
                    danceName: danceName,
                    rhythm: fig.1,
                    isCustom: false
                )
                context.insert(item)
                existingSet.insert(key)
            }
        }
        try? context.save()
    }
}

@Model
final class InstantNote {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var text: String
    var videoPath: String?
    var imagePath: String?
    /// Voice recording (file name in Documents, AAC .m4a). The recording is the note; the dancer listens
    /// to it later and writes down what matters in `text`.
    var audioPath: String? = nil
    var audioDuration: Double? = nil
    /// Dance the note belongs to (e.g. "Waltz"); nil = general note.
    var danceName: String? = nil
    var isPinned: Bool = false
    var linkedFigureId: UUID? = nil
    var linkedRoutineId: UUID? = nil
    /// Set when the note was imported into a figure; the note itself is kept (undo-able).
    var importedAt: Date? = nil

    init(id: UUID = UUID(), createdAt: Date = Date(), text: String = "", videoPath: String? = nil, imagePath: String? = nil,
         audioPath: String? = nil, audioDuration: Double? = nil, danceName: String? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.videoPath = videoPath
        self.imagePath = imagePath
        self.audioPath = audioPath
        self.audioDuration = audioDuration
        self.danceName = danceName
    }

    var isImported: Bool { importedAt != nil }
}

import UIKit
extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
