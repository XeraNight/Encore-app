import Foundation
import Network
import Observation

/// Whether the iPhone has a network right now, and a way to wait for one. It only says that a route exists: a weak
/// or captive Wi-Fi still counts as online, so whoever waits for a page keeps its own time limit.
@MainActor
@Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isOnline = true
    private let monitor = NWPathMonitor()

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "encore.network-monitor"))
    }

    /// Waits until the network is back. False when it did not come back within `timeout` seconds, or the caller was
    /// cancelled.
    func waitUntilOnline(timeout: TimeInterval) async -> Bool {
        await ConnectionWait.until({ NetworkMonitor.shared.isOnline }, timeout: timeout)
    }
}

/// Waits for a condition, looking now and then, up to a time limit. Someone waiting for a network does not need it
/// faster, and looking at a flag on the iPhone costs nothing.
enum ConnectionWait {
    static func until(_ condition: () -> Bool, timeout: TimeInterval, every interval: TimeInterval = 0.5) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Task.isCancelled || Date() >= deadline { return false }
            try? await Task.sleep(for: .seconds(interval))
        }
        return true
    }
}
