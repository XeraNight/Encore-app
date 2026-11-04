import Foundation

/// Dances are stored under their international names ("Viennese Waltz"), which the cloud, KSIS and
/// shared routines use. People read them the way Slovak dancers say them. Pure text, usable from any thread.
nonisolated enum DanceNames {
    /// Standard first, then Latin, in the order they are danced at a competition.
    static let order = ["Waltz", "Tango", "Viennese Waltz", "Slowfoxtrot", "Quickstep",
                        "Samba", "Cha-Cha-Cha", "Rumba", "Paso Doble", "Jive"]

    static func display(_ stored: String) -> String {
        switch stored {
        case "Viennese Waltz": return "Viedenský valčík"
        case "Slowfoxtrot": return "Slowfox"
        case "Cha-Cha-Cha": return "Cha-cha-cha"
        case "Paso Doble": return "Paso doble"
        default: return stored
        }
    }

    /// Position for sorting; unknown dances go last.
    static func rank(_ stored: String) -> Int {
        order.firstIndex(of: stored) ?? order.count
    }
}
