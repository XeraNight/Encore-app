import Foundation

// MARK: - Features held back for a later version
/// Switches in code, never from the server: Apple does not allow hidden features that turn on without review
/// (App Review 2.3.1). Turning one on means a new version that goes through review. The code, the database
/// tables and the server functions behind them stay as they are. See `docs/V1_REMAINING_WORK.md`.
nonisolated enum AppFeatures {
    /// Coach role, students, lessons ("čo sme robili naposledy"), coach notes on figures and guest coach keys.
    static let coachTools = false
    /// Sharing figure videos with partner and coach (720p copy on Cloudflare R2). Videos stay in Fotky.
    static let sharedVideos = false
}
