import AVFoundation

// MARK: - AudioSessionCoordinator
actor AudioSessionCoordinator {

    static let shared = AudioSessionCoordinator()
    private init() {}

    enum Client: String {
        case player, mutedVideo, speech, voiceNote
    }

    private var activeClient: Client?
    private let avSession = AVAudioSession.sharedInstance()

    func activate(_ client: Client) async throws {
        // Ak iný klient drží session, bezpečne ho odovzdaj
        if let current = activeClient, current != client {
            try avSession.setActive(false, options: .notifyOthersOnDeactivation)
        }

        switch client {
        case .player:
            // Playback already routes to AirPlay and Bluetooth headphones on its own. The HFP and AirPlay
            // options are only valid with .playAndRecord; passing them here made setCategory fail (-50).
            try avSession.setCategory(.playback, mode: .moviePlayback)
            try avSession.setActive(true)

        case .mutedVideo:
            // A silent figure video must never stop music already playing in the hall (Spotify, a speaker).
            try avSession.setCategory(.ambient, mode: .default)
            try avSession.setActive(true)

        case .voiceNote:
            // Plain voice recording and playback of it: default mode (no measurement/raw processing),
            // no Bluetooth hands-free input (it would drop the recording to phone-call quality).
            try avSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try avSession.setPreferredSampleRate(48_000)
            try avSession.setActive(true)

        case .speech:
            try avSession.setCategory(
                .record,
                mode: .measurement,
                options: [.duckOthers]
            )
            try avSession.setActive(true)
        }

        activeClient = client
    }

    func deactivate(_ client: Client) async {
        guard activeClient == client else { return }
        try? avSession.setActive(false, options: .notifyOthersOnDeactivation)
        activeClient = nil
    }

    var currentClient: Client? { activeClient }
}
