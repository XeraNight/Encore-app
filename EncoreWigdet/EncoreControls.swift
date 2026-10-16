import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Controls (Lock Screen, Control Center, Action button)
/// One tap from the Lock Screen into Encore. Each control opens a universal link, the only way Apple supports
/// for opening an app from a control; the app (`QuickAction`) turns it into the camera, a voice note, a text
/// note or KSIS.
private func quickURL(_ action: String) -> URL {
    URL(string: "https://www.encore-sk.com/quick/\(action)") ?? URL(filePath: "/")
}

struct EncoreVideoControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.jakub.encore.control.video") {
            ControlWidgetButton(action: OpenURLIntent(quickURL("video"))) {
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
            ControlWidgetButton(action: OpenURLIntent(quickURL("voice"))) {
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
            ControlWidgetButton(action: OpenURLIntent(quickURL("text"))) {
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
            ControlWidgetButton(action: OpenURLIntent(quickURL("ksis"))) {
                Label("Kalendár súťaží", systemImage: "trophy.fill")
            }
        }
        .displayName("Kalendár súťaží")
        .description("Otvorí kalendár súťaží v KSIS, s prihláškami ku každému podujatiu.")
    }
}
