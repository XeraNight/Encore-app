import OSLog

// MARK: - Encore Centralised Logging
//
// Uses Apple's unified os_log system via the modern Logger API (iOS 14+).
// Advantages over print():
//   • Automatically disabled in Release builds (privacy redaction)
//   • Filterable by category in Console.app and Instruments
//   • Zero overhead in production — compiled out by the OS
//   • Privacy-aware: use `privacy: .public` only for non-sensitive data
//
// Usage:
//   Logger.sync.info("Synced routine '\(name, privacy: .public)'")
//   Logger.auth.error("Sign-in failed: \(error.localizedDescription, privacy: .public)")

extension Logger {
    private static let subsystem = "com.encore.app"

    /// Authentication, session management, biometrics, Google Sign-In.
    nonisolated static let auth     = Logger(subsystem: subsystem, category: "auth")

    /// Supabase database sync, upserts, deletes, debouncing.
    nonisolated static let sync     = Logger(subsystem: subsystem, category: "sync")

    /// Supabase Realtime WebSocket — connect, broadcast, presence, disconnect.
    nonisolated static let realtime = Logger(subsystem: subsystem, category: "realtime")

    /// Canvas gestures, node management, draw mode, QR export.
    nonisolated static let canvas   = Logger(subsystem: subsystem, category: "canvas")

    /// AVFoundation camera, recording, Live Activity, Dynamic Island.
    nonisolated static let camera   = Logger(subsystem: subsystem, category: "camera")

    /// Speech recognition, audio session, metronome.
    nonisolated static let audio    = Logger(subsystem: subsystem, category: "audio")

    /// General / uncategorised — use sparingly.
    nonisolated static let general  = Logger(subsystem: subsystem, category: "general")
    nonisolated static let analytics = Logger(subsystem: subsystem, category: "analytics")
}
