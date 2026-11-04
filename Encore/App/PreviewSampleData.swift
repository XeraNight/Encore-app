//
//  PreviewSampleData.swift
//  Encore
//
//  Shared, high-performance in-memory ModelContainer for Xcode SwiftUI Previews (#Preview).
//  Initialized once and cached in RAM to deliver instantaneous ("bleskové") live rendering in Xcode Canvas.
//

import SwiftUI
import SwiftData

@MainActor
public enum PreviewSampleData {
    /// Cached static in-memory ModelContainer for SwiftUI Previews
    public static let container: ModelContainer = {
        let schema = Schema([
            Dance.self,
            FigureLibraryItem.self,
            Routine.self,
            CanvasNode.self,
            InstantNote.self,
            VideoMediaEntry.self
        ])
        
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = container.mainContext
            
            // ── 1. Dances (Standard & Latin) ──
            let waltz = Dance(
                name: "Waltz",
                category: "Standard",
                tempo: "28–30 MPM",
                info: "Rise & Fall, Sway, plynulý swingový pohyb."
            )
            let tango = Dance(
                name: "Tango",
                category: "Standard",
                tempo: "31–33 MPM",
                info: "Staccato akcenty, kompaktné držanie, bez Rise & Fall."
            )
            let vienneseWaltz = Dance(
                name: "Viennese Waltz",
                category: "Standard",
                tempo: "58–60 MPM",
                info: "Rýchla rotácia a plynulosť."
            )
            let rumba = Dance(
                name: "Rumba",
                category: "Latin",
                tempo: "25–27 MPM",
                info: "Pohyb panvy z centra tela, jednotka sa netancuje."
            )
            let chacha = Dance(
                name: "Cha-Cha-Cha",
                category: "Latin",
                tempo: "30–32 MPM",
                info: "Ostrý rytmus, prepnuté kolená, akcent na 1."
            )
            let samba = Dance(
                name: "Samba",
                category: "Latin",
                tempo: "48–50 MPM",
                info: "Samba bounce, práca s ťažiskom v rytme 1 a 2."
            )
            
            context.insert(waltz)
            context.insert(tango)
            context.insert(vienneseWaltz)
            context.insert(rumba)
            context.insert(chacha)
            context.insert(samba)
            
            // ── 2. Sample Routines ──
            let waltzRoutine = Routine(
                name: "MSR 2026 Finálová zostava",
                danceName: "Waltz",
                danceCategory: "Standard",
                createdAt: Date(),
                updatedAt: Date()
            )
            let rumbaRoutine = Routine(
                name: "Základná tréningová zostava",
                danceName: "Rumba",
                danceCategory: "Latin",
                createdAt: Date().addingTimeInterval(-86400),
                updatedAt: Date().addingTimeInterval(-3600)
            )
            context.insert(waltzRoutine)
            context.insert(rumbaRoutine)
            
            // ── 3. Canvas Nodes for Waltz Routine ──
            let node1 = CanvasNode(
                x: 120,
                y: 180,
                figureName: "Natural Spin Turn",
                rhythm: "1 2 3",
                notes: "Klesanie na konci 3, rotácia z centra tela.",
                orderIndex: 0,
                transitionNotes: "Plynulý swing do rohu sály",
                masteryRating: 4
            )
            node1.routine = waltzRoutine
            
            let node2 = CanvasNode(
                x: 300,
                y: 180,
                figureName: "Reverse Turn",
                rhythm: "1 2 3",
                notes: "Hlava partnerky ostáva vľavo.",
                orderIndex: 1,
                transitionNotes: "Zníženie a nášľap na pätu",
                masteryRating: 5
            )
            node2.routine = waltzRoutine
            
            let node3 = CanvasNode(
                x: 480,
                y: 180,
                figureName: "Whisk",
                rhythm: "1 2 3",
                notes: "Kríženie nôh vzadu s flexibilnými členkami.",
                orderIndex: 2,
                transitionNotes: "Otvorenie do promenády",
                masteryRating: 3
            )
            node3.routine = waltzRoutine
            
            context.insert(node1)
            context.insert(node2)
            context.insert(node3)
            
            // ── 4. Sample Figures for Library ──
            context.insert(FigureLibraryItem(name: "Natural Spin Turn", danceName: "Waltz", rhythm: "1 2 3", techniqueNotes: "Rise & Fall, silný drive"))
            context.insert(FigureLibraryItem(name: "Whisk", danceName: "Waltz", rhythm: "1 2 3", techniqueNotes: "Základná promenádna figúra"))
            context.insert(FigureLibraryItem(name: "Chassé from Promenade", danceName: "Waltz", rhythm: "1 2& 3", techniqueNotes: "Rýchly synkopovaný krok"))
            context.insert(FigureLibraryItem(name: "Open Hip Twist", danceName: "Rumba", rhythm: "2 3 4 1", techniqueNotes: "Presné vedenie rukou na 4 1"))
            context.insert(FigureLibraryItem(name: "Alemana", danceName: "Rumba", rhythm: "2 3 4 1", techniqueNotes: "Otáčka dámy pod ramenom"))
            context.insert(FigureLibraryItem(name: "Lock Step", danceName: "Cha-Cha-Cha", rhythm: "4 & 1", techniqueNotes: "Rýchly lock na špičkách"))
            
            // ── 5. Instant Notes ──
            context.insert(InstantNote(
                createdAt: Date(),
                text: "Tréning: Pri Spin Turne držať pravé rameno stabilné a nezalamovať zápästie. #Waltz #Držanie"
            ))
            context.insert(InstantNote(
                createdAt: Date().addingTimeInterval(-43200),
                text: "Rumba Walk: Váhu prenášať plynulo cez celé chodidlo až na špičku. #Rumba"
            ))
            
            try? context.save()
            return container
        } catch {
            fatalError("Failed to initialize PreviewSampleData container: \(error)")
        }
    }()
}

// MARK: - View Extension for Lightning-Fast Previews
public extension View {
    /// Wraps the view in the shared in-memory ModelContainer and dark color scheme for instantaneous live previews.
    func previewWithSampleData() -> some View {
        self
            .modelContainer(PreviewSampleData.container)
            .preferredColorScheme(.dark)
    }
}
