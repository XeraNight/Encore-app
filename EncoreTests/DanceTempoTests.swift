import Foundation
import SwiftData
import Testing
@testable import Encore

/// The metronome says takty za minútu ("29"), as dancers and SZTŠ do, and clicks the beats that come from them.
@MainActor
struct DanceTempoTests {
    private let dances = DanceMetronomePreset.allCases.filter { $0 != .off }

    @Test func theTempoIsTheOneSZTSPrescribes() {
        // Súťažný poriadok SZTŠ 2023, čl. 8 bod 2 (the same as WDSF).
        let expected: [DanceMetronomePreset: ClosedRange<Int>] = [
            .waltz: 28...30, .tango: 31...33, .vienneseWaltz: 58...60, .slowfox: 28...30, .quickstep: 50...52,
            .samba: 50...52, .chacha: 30...32, .rumba: 25...27, .pasoDoble: 60...62, .jive: 42...44,
        ]
        for (dance, range) in expected { #expect(dance.competitionMeasures == range, "\(dance.shortCode)") }
        #expect(DanceMetronomePreset.off.competitionMeasures == nil)
        #expect(dances.count == 10)
    }

    @Test func theBasicTempoIsTheMiddleOfTheRangeAndTheClicksAreTaktyTimesBeats() {
        let middle: [DanceMetronomePreset: Double] = [
            .waltz: 29, .tango: 32, .vienneseWaltz: 59, .slowfox: 29, .quickstep: 51,
            .samba: 51, .chacha: 31, .rumba: 26, .pasoDoble: 61, .jive: 43,
        ]
        // What the metronome clicked before its numbers came from the one table: nothing changes for the ear.
        let clicks: [DanceMetronomePreset: Double] = [
            .waltz: 87, .tango: 128, .vienneseWaltz: 177, .slowfox: 116, .quickstep: 204,
            .samba: 102, .chacha: 124, .rumba: 104, .pasoDoble: 122, .jive: 172,
        ]
        for dance in dances {
            #expect(dance.mpm == middle[dance], "\(dance.shortCode) takty")
            #expect(dance.bpm == clicks[dance], "\(dance.shortCode) clicks")
        }
        let threeBeats: [DanceMetronomePreset] = [.waltz, .vienneseWaltz]
        let twoBeats: [DanceMetronomePreset] = [.samba, .pasoDoble]
        #expect(threeBeats.allSatisfy { $0.beatsPerMeasure == 3 })
        #expect(twoBeats.allSatisfy { $0.beatsPerMeasure == 2 })
        #expect(DanceMetronomePreset.off.bpm == 0)
    }

    @Test func aTempoAgainstTheOneOfTheCompetition() {
        let waltz = DanceMetronomePreset.waltz
        #expect(waltz.compare(measures: 28) == CompetitionTempo.within)
        #expect(waltz.compare(measures: 30) == CompetitionTempo.within)
        #expect(waltz.compare(measures: 27) == CompetitionTempo.slower(by: 1))
        #expect(waltz.compare(measures: 31) == CompetitionTempo.faster(by: 1))
        #expect(waltz.compare(measures: 20) == CompetitionTempo.slower(by: 8))
        #expect(DanceMetronomePreset.off.compare(measures: 29) == nil)
    }

    @Test func theEngineSaysTaktyAndWholeClicksWithoutARoundingSlip() {
        let engine = DanceMetronomeEngine.shared
        defer {
            engine.selectedPreset = .off
            engine.tempoMultiplier = 1
        }
        engine.selectedPreset = .waltz
        engine.tempoMultiplier = 1
        #expect(engine.effectiveMpm == 29)
        #expect(engine.effectiveBpm == 87)
        #expect(engine.againstCompetition == CompetitionTempo.within)

        // Practice at 90 %: 78 clicks, 26 takty, two under the competition tempo.
        engine.tempoMultiplier = 0.9
        #expect(engine.effectiveBpm == 78)
        #expect(engine.effectiveMpm == 26)
        #expect(engine.againstCompetition == CompetitionTempo.slower(by: 2))

        // One takt up from 29 is 30 takty: 90 clicks, not 89 from a floating point slip.
        engine.tempoMultiplier = Double(30 * 3) / DanceMetronomePreset.waltz.bpm
        #expect(engine.effectiveBpm == 90)
        #expect(engine.effectiveMpm == 30)

        engine.selectedPreset = .samba
        engine.tempoMultiplier = 1
        #expect(engine.effectiveMpm == 51)
        #expect(engine.effectiveBpm == 102)

        engine.selectedPreset = .off
        #expect(engine.effectiveMpm == 0)
        #expect(engine.effectiveBpm == 0)
        #expect(engine.againstCompetition == nil)
    }
}

/// The dance library says the tempo in takty, from the same table as the metronome.
@MainActor
struct DanceLibraryTempoTests {
    private let libraryNames = ["Waltz", "Tango", "Viennese Waltz", "Slowfoxtrot", "Quickstep", "Samba", "Cha-Cha-Cha", "Rumba", "Paso Doble", "Jive"]

    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([Dance.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        return (container, container.mainContext)
    }

    @Test func everyDanceOfTheLibraryHasItsTempoTextFromTheOneTable() throws {
        #expect(DanceMetronomePreset.waltz.tempoText == "28–30 taktov za minútu (84–90 úderov)")
        #expect(DanceMetronomePreset.samba.tempoText == "50–52 taktov za minútu (100–104 úderov)")
        #expect(DanceMetronomePreset.pasoDoble.tempoText == "60–62 taktov za minútu (120–124 úderov)")
        #expect(DanceMetronomePreset.off.tempoText == nil)
        for name in libraryNames {
            let preset = try #require(DanceMetronomePreset.forLibraryDance(name), "\(name)")
            let text = try #require(preset.tempoText)
            // A routine's length is counted from this text: the takty before the bracket are the metronome's middle.
            #expect(RoutineTiming.barsPerMinute(fromTempo: text) == preset.mpm, "\(name)")
        }
        #expect(DanceMetronomePreset.forLibraryDance("Polka") == nil)
    }

    @Test func aLibrarySeededBeforeTaktyGetsTheTempoSZTSPrescribesAndKeepsWhatTheDancerEdited() throws {
        let (store, context) = try makeContext()
        defer { withExtendedLifetime(store) {} }
        let samba = Dance(name: "Samba", category: "Latin", tempo: "48–50 MPM (96–100 BPM)", info: "")
        let waltz = Dance(name: "Waltz", category: "Standard", tempo: "28–30 MPM (84–90 BPM)", info: "")
        let edited = Dance(name: "Tango", category: "Standard", tempo: "30 taktov, pomalšie na hodinu", info: "")
        let own = Dance(name: "Polka", category: "Standard", tempo: "28–30 MPM (84–90 BPM)", info: "")
        [samba, waltz, edited, own].forEach(context.insert)
        try context.save()

        EncoreApp.updateSeededTempoTexts(in: context)
        #expect(samba.tempo == "50–52 taktov za minútu (100–104 úderov)")
        #expect(waltz.tempo == "28–30 taktov za minútu (84–90 úderov)")
        #expect(edited.tempo == "30 taktov, pomalšie na hodinu")
        #expect(own.tempo == "28–30 MPM (84–90 BPM)")

        // Once more changes nothing.
        EncoreApp.updateSeededTempoTexts(in: context)
        #expect(samba.tempo == "50–52 taktov za minútu (100–104 úderov)")
    }
}
