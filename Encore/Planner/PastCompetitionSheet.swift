import SwiftData
import SwiftUI

// MARK: - A competition that has been danced
/// Opens from "Minulé" in Súťaže: the results of that day, each opening its round-by-round marks; when none are
/// saved yet, a button reads them from KSIS. The plan (Idem / Neidem, city, category) stays one tap away.
struct PastCompetitionSheet: View {
    let competition: PlannedCompetition

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = CompetitionManager.shared
    @State private var detail: CompetitionResult?
    @State private var browser: KSISBrowserTarget?
    @State private var updateJob: KSISUpdateJob?
    @State private var showEditor = false

    private var results: [CompetitionResult] { competition.dancedResults(in: manager.results) }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if results.isEmpty {
                            notSavedCard
                        } else {
                            HomeSectionHeader(title: "VÝSLEDKY", systemImage: "trophy.fill", count: results.count)
                            ForEach(results) { result in
                                Button { detail = result } label: {
                                    CompetitionResultRow(result: result, isMissingMarks: manager.isMissingMarks(result))
                                        .homeCard(cornerRadius: 16)
                                }
                                .buttonStyle(.pressable(scale: 0.98))
                                .accessibilityHint("Otvorí hodnotenie")
                            }
                        }
                        Button { showEditor = true } label: {
                            Label("Upraviť súťaž v pláne", systemImage: "slider.horizontal.3")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(Color.gold400)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.pressable)
                    }
                    .padding(20)
                }
                .softTopEdge()
            }
            .navigationTitle("Súťaž")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavrieť") { dismiss() }.foregroundColor(Color.gold400)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $detail) { result in
            KSISResultDetailView(result: result) { browser = KSISBrowserTarget(url: $0) }
        }
        .sheet(isPresented: $showEditor) { CompetitionEditorSheet(competition: competition) }
        .fullScreenCover(item: $browser) { KSISBrowserView(startURL: $0.url) }
        .fullScreenCover(item: $updateJob) { KSISUpdateSheet(job: $0) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(competition.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()).uppercased())
                .font(.system(.caption, design: .rounded).weight(.black))
                .tracking(1.2)
                .foregroundColor(Color.gold400)
            Text(competition.name)
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundColor(.white)
            if !competition.city.isEmpty {
                Text(competition.city)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.65))
            }
        }
    }

    private var notSavedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Výsledky z tejto súťaže nemáš uložené", systemImage: "tray")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
            // The update starts from the dancer's couples, so without a picked dancer KSIS opens first and says what to do.
            Text(manager.dancer == nil
                 ? "Najprv sa nájdi v KSIS. Potom ti Encore vie prečítať výsledky: miesto, body aj hodnotenie rozhodcov."
                 : "Ak si tancoval, Encore ich vie prečítať z KSIS: miesto, body aj hodnotenie rozhodcov.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            if manager.dancer != nil {
                Button { updateJob = .everything } label: {
                    Label("Načítať výsledky z KSIS", systemImage: "arrow.down.circle")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color.obsidian900)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color.gold400, in: Capsule())
                }
                .buttonStyle(.pressable)
            }
            Button {
                if let url = KSISBrowserView.page("menu.php?akcia=S") { browser = KSISBrowserTarget(url: url) }
            } label: {
                Label("Pozrieť v KSIS", systemImage: "safari")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.gold400)
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.pressable)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 20)
    }
}
