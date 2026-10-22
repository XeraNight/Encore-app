import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins

struct QRSharePayload: Codable {
    /// Older codes carried the routine's ID; it is read but never used (an import is always a new copy).
    let id: String?
    let n: String // name
    let d: String // danceName
    let c: String // danceCategory
    let nodes: [QRShareNode]
}

struct QRShareNode: Codable {
    /// Older codes carried the figure's ID; ignored like the routine's.
    let id: String?
    let x: Double
    let y: Double
    let f: String // figureName
    let r: String? // rhythm (optional for backward compatibility)
    let n: String? // notes (optional for backward compatibility)
    let o: Int    // orderIndex
    let t: String? // transitionNotes (optional for backward compatibility)
}

// MARK: - Import a shared routine (QR or pasted code)
enum RoutineShareImportError: LocalizedError {
    case unreadable, tooManyFigures, invalidContent

    var errorDescription: String? {
        switch self {
        case .unreadable: return "Nepodarilo sa naimportovať zostavu."
        case .tooManyFigures: return "QR kód obsahuje príliš veľa figúr (max. 200)."
        case .invalidContent: return "QR kód obsahuje neplatné dáta."
        }
    }
}

enum RoutineShareImporter {
    /// Creates a new copy of the routine and returns its name. Always new IDs: a code from someone else must
    /// never overwrite one of your routines, and a copy must not share the original's live channel. The content
    /// is checked like anything from outside: short texts, figures on the floor.
    static func importRoutine(fromCode rawCode: String, into context: ModelContext) throws -> String {
        let trimmed = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let payload = try? JSONDecoder().decode(QRSharePayload.self, from: data) else {
            throw RoutineShareImportError.unreadable
        }
        guard payload.nodes.count <= 200 else { throw RoutineShareImportError.tooManyFigures }
        let name = payload.n.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 120, payload.d.count <= 80, payload.c.count <= 40 else {
            throw RoutineShareImportError.invalidContent
        }

        let routine = Routine(id: UUID(), name: name, danceName: payload.d, danceCategory: payload.c)
        context.insert(routine)
        let floor = BallroomFloorConfig.safeCardBounds(cardWidth: 40, cardHeight: 40, wallMargin: 8)
        for (index, raw) in payload.nodes.enumerated() {
            let x = raw.x.isFinite ? min(max(raw.x, floor.minX), floor.maxX) : BallroomFloorConfig.centerPoint.x
            let y = raw.y.isFinite ? min(max(raw.y, floor.minY), floor.maxY) : BallroomFloorConfig.centerPoint.y
            let node = CanvasNode(
                id: UUID(), x: x, y: y, figureName: String(raw.f.prefix(80)), rhythm: String((raw.r ?? "").prefix(80)),
                notes: String((raw.n ?? "").prefix(5000)), orderIndex: (0...200).contains(raw.o) ? raw.o : index,
                transitionNotes: String((raw.t ?? "").prefix(500))
            )
            node.routine = routine
            context.insert(node)
        }

        do {
            try context.save()
        } catch {
            throw RoutineShareImportError.unreadable
        }
        SupabaseSyncManager.shared.syncRoutineOnBackground(routine)
        return name
    }
}

struct QRGenerator {
    static func generatePayload(from routine: Routine) -> String? {
        let shareNodes = routine.canvasNodes.map { node in
            QRShareNode(
                id: nil,
                x: node.x,
                y: node.y,
                f: node.figureName,
                r: node.rhythm,
                n: node.notes,
                o: node.orderIndex,
                t: node.transitionNotes
            )
        }
        let payload = QRSharePayload(
            id: nil,   // a code carries no IDs: whoever scans it gets a copy, not a way into this routine
            n: routine.name,
            d: routine.danceName,
            c: routine.danceCategory,
            nodes: shareNodes
        )
        guard let data = try? JSONEncoder().encode(payload),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
    
    /// Runs off the main thread. Returns nil when the text does not fit into a QR code
    /// (about 2.9 kB with the lowest error correction).
    nonisolated static func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "L"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Upscale the QR image (it's naturally small/pixelated)
        let scaleX = 300.0 / outputImage.extent.size.width
        let scaleY = 300.0 / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
