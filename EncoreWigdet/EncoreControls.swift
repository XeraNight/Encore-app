import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Controls (Lock Screen, Control Center, Action button)
/// One tap from the Lock Screen into Encore. Apple opens an app from a control only through an `OpenIntent`
/// that is in both the app and the widget extension, so this file is in both targets. The system opens Encore and
/// runs the intent there; the app's `perform()` (QuickActions.swift) takes it to the camera, a voice note, a text
/// note or KSIS. A universal link returned from the intent is dropped, so the intent names the screen itself.

/// What a control opens; the raw values are the `QuickAction` cases.
enum QuickControlTarget: String, AppEnum {
    case video, voice, text, ksis

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Obrazovka Encore"
    static var caseDisplayRepresentations: [QuickControlTarget: DisplayRepresentation] = [
        .video: "Natočiť video",
        .voice: "Hlasová poznámka",
        .text: "Poznámka",
        .ksis: "Kalendár súťaží",
    ]
}

struct OpenQuickActionIntent: OpenIntent {
    static var title: LocalizedStringResource = "Otvoriť Encore"

    @Parameter(title: "Obrazovka")
    var target: QuickControlTarget

    init() {}

    init(_ target: QuickControlTarget) {
        self.target = target
    }
}

struct EncoreVideoControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.jakub.encore.control.video") {
            ControlWidgetButton(action: OpenQuickActionIntent(.video)) {
                Label("Natočiť video", systemImage: "video.fill")
            }
        }
        .displayName("Natočiť video")
        .description("Otvorí kameru Encore. Video sa uloží do Fotiek a medzi poznámky.")
    }
}

struct EncoreVoiceControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.jakub.encore.control.voice") {
            ControlWidgetButton(action: OpenQuickActionIntent(.voice)) {
                Label("Hlasová poznámka", systemImage: "mic.fill")
            }
        }
        .displayName("Hlasová poznámka")
        .description("Hneď nahráva hlasovú poznámku, napríklad čo povedal tréner.")
    }
}

struct EncoreTextControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.jakub.encore.control.text") {
            ControlWidgetButton(action: OpenQuickActionIntent(.text)) {
                Label("Poznámka", systemImage: "square.and.pencil")
            }
        }
        .displayName("Poznámka")
        .description("Otvorí Encore rovno na písanie poznámky.")
    }
}

struct EncoreKSISControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.jakub.encore.control.ksis") {
            ControlWidgetButton(action: OpenQuickActionIntent(.ksis)) {
                Label("Kalendár súťaží", systemImage: "trophy.fill")
            }
        }
        .displayName("Kalendár súťaží")
        .description("Otvorí kalendár súťaží v KSIS, s prihláškami ku každému podujatiu.")
    }
}
