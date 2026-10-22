import Foundation
import SwiftUI
import Combine
import OSLog
import Supabase

// MARK: - Remote Config Payload
/// One row of `public.app_config` (migration 20261009_app_config.sql), readable by everyone.
struct RemoteConfigPayload: Codable {
    let min_version: String?
    let maintenance_mode: Bool?
    let maintenance_message: String?
    let app_store_url: String?
}

// MARK: - Remote Config & Emergency Precautions Manager
/// Force update and maintenance notice, set in Supabase → Table Editor → `app_config`.
@MainActor
final class RemoteConfigManager: ObservableObject {
    static let shared = RemoteConfigManager()

    private let cacheKey = "encore_remote_config_cache"

    @Published var isMaintenanceMode: Bool = false
    @Published var maintenanceMessage: String = "Prebieha plánovaná údržba. Tvoje tréningy v telefóne fungujú bez obmedzení."
    @Published var needsForceUpdate: Bool = false
    @Published var appStoreURL: URL? = nil
    /// Launch and every return to the foreground both ask; once every 15 minutes is enough.
    private var lastSyncAttempt: Date?
    private let minimumSyncInterval: TimeInterval = 15 * 60

    private init() {
        loadCachedConfig()
    }

    // MARK: - Fetch Config on App Launch or Scene Foreground
    func syncConfig() async {
        if let lastSyncAttempt, Date().timeIntervalSince(lastSyncAttempt) < minimumSyncInterval { return }
        lastSyncAttempt = Date()

        do {
            let data = try await SupabaseConfig.client
                .from("app_config")
                .select("min_version, maintenance_mode, maintenance_message, app_store_url")
                .single()
                .execute()
                .data
            let decoded = try JSONDecoder().decode(RemoteConfigPayload.self, from: data)
            applyConfig(decoded)

            // Cache successful payload
            UserDefaults.standard.set(data, forKey: cacheKey)
        } catch {
            Logger.general.notice("RemoteConfig sync failed, using cache or defaults: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Apply Decoded Config
    private func applyConfig(_ payload: RemoteConfigPayload) {
        if let maintenance = payload.maintenance_mode {
            self.isMaintenanceMode = maintenance
        }
        if let message = payload.maintenance_message, !message.isEmpty {
            self.maintenanceMessage = message
        }
        if let storeStr = payload.app_store_url, let storeURL = URL(string: storeStr) {
            self.appStoreURL = storeURL
        }
        
        // Version Check (Force Update)
        if let minVersion = payload.min_version {
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            self.needsForceUpdate = isVersion(appVersion, olderThan: minVersion)
        }
    }
    
    private func loadCachedConfig() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let decoded = try? JSONDecoder().decode(RemoteConfigPayload.self, from: data) else {
            return
        }
        applyConfig(decoded)
    }
    
    private func isVersion(_ v1: String, olderThan v2: String) -> Bool {
        v1.compare(v2, options: .numeric) == .orderedAscending
    }
}

// MARK: - Full-screen notices (BRAND_GUIDELINES §1A)
/// The app cannot go on as usual: an update is required, or the servers are down for maintenance.
private struct ServiceNotice<Action: View>: View {
    let icon: String
    let title: String
    let message: String
    @ViewBuilder var action: Action

    var body: some View {
        ZStack {
            EllegancePageBackground()
            VStack(spacing: 22) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(Color.gold400)
                    .frame(width: 84, height: 84)
                    .background(Color.gold500.opacity(0.14), in: Circle())
                    .overlay(Circle().stroke(Color.gold400.opacity(0.4), lineWidth: 1.5))
                    .accessibilityHidden(true)
                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                    Text(message)
                        .font(.body)
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.center)
                }
                action
            }
            .padding(.horizontal, 32)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Force Update Modal Overlay
struct ForceUpdateView: View {
    let appStoreURL: URL?

    var body: some View {
        ServiceNotice(icon: "arrow.down.circle.fill", title: "Dôležitá aktualizácia",
                      message: "Táto verzia Encore už nefunguje so serverom. Stiahni si najnovšiu z App Store, tvoje dáta ostanú.") {
            if let url = appStoreURL {
                Link(destination: url) {
                    Label("Aktualizovať v App Store", systemImage: "arrow.down.app.fill")
                        .font(.headline)
                        .foregroundColor(Color.obsidian900)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Color.gold400, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.pressable)
            }
        }
    }
}

// MARK: - Maintenance Notice Modal Overlay
struct MaintenanceNoticeView: View {
    let message: String
    let onContinueOffline: () -> Void

    var body: some View {
        ServiceNotice(icon: "wrench.and.screwdriver.fill", title: "Prebieha údržba", message: message) {
            Button {
                HapticFeedback.light()
                onContinueOffline()
            } label: {
                Label("Pokračovať bez internetu", systemImage: "icloud.slash")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.pressable)
        }
    }
}
