import OSLog
import Supabase
import SwiftUI

// MARK: - A connection's results
/// The KSIS class, points and saved competitions of someone I am connected with, read-only (BRAND_GUIDELINES §1A).
/// Only there when they switched on Ukazovať moje výsledky spojeniam: the server checks it (shares_results_with).
struct ConnectionResultsSheet: View {
    let connection: DancerConnection
    let couple: UserCouple

    @Environment(\.dismiss) private var dismiss
    @State private var results: [CompetitionResult] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var selected: CompetitionResult?

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        HomeSectionHeader(title: "SÚŤAŽE", systemImage: "trophy.fill", count: results.isEmpty ? nil : results.count)
                        if isLoading {
                            ProgressView().tint(Color.gold400).frame(maxWidth: .infinity).padding(.vertical, 24)
                        } else if loadFailed {
                            hint("Súťaže sa nepodarilo načítať. Skontroluj pripojenie.")
                        } else if results.isEmpty {
                            hint("Zatiaľ nemá uložené žiadne súťaže.")
                        } else {
                            ForEach(results) { result in
                                Button { selected = result } label: { row(result) }
                                    .buttonStyle(.pressable(scale: 0.98))
                            }
                        }
                    }
                    .padding(20)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: results.count)
                }
            }
            .navigationTitle(connection.otherUserName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zavrieť") { dismiss() } }
            }
            .sheet(item: $selected) { result in
                KSISResultDetailView(result: result, onOpenKSIS: { _ in }, isOwn: false)
            }
            .task { await load() }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(couple.partnerNames ?? connection.otherUserName)
                .font(.headline)
                .foregroundColor(.white)
            HStack(spacing: 8) {
                standing("ŠTT", couple.stt)
                standing("LAT", couple.lat)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 18)
    }

    private func standing(_ label: String, _ value: UserCouple.Standing) -> some View {
        let parts = ["\(label) \(value.className ?? "–")", value.points.map { "\($0) b" }, value.finals.map { "\($0) F" }]
        return Text(parts.compactMap { $0 }.joined(separator: " · "))
            .font(.caption.weight(.bold))
            .foregroundColor(Color.gold300)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.gold500.opacity(0.14), in: Capsule())
    }

    private func row(_ result: CompetitionResult) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(result.eventName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(result.categoryName) · \(result.date)")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
            Spacer(minLength: 8)
            Text(result.placeLine)
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundColor(Color.gold300)
        }
        .padding(12)
        .homeCard(cornerRadius: 14)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundColor(.white.opacity(0.7))
            .padding(.vertical, 8)
    }

    private func load() async {
        defer { isLoading = false }
        do {
            results = try await SupabaseConfig.client
                .from("competition_results")
                .select("id, sutaz_id, couple_id, event_name, category_name, discipline, date, couple_count, placement_text, placement, points_earned, cumulative_stats, start_number, rounds, judges")
                .eq("user_id", value: connection.otherUserId)
                .eq("is_deleted", value: false)
                .order("date", ascending: false)
                .execute()
                .value
        } catch {
            loadFailed = true
            Logger.sync.error("A connection's results failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
