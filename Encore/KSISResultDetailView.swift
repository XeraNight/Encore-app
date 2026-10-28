import SwiftUI

// MARK: - One competition in detail
/// Place, points and, round by round, the mark of every published judge. "Suma" is always KSIS's own
/// number; a judge KSIS hides is named and counted, never guessed per dance (docs/KSIS_AUTO_CONNECT_PLAN.md §6).
struct KSISResultDetailView: View {
    let result: CompetitionResult
    /// Opens a KSIS page in the app (the comparison sheet closes first).
    let onOpenKSIS: (URL) -> Void
    /// False for a connection's result: it can be read, not removed.
    var isOwn = true

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = CompetitionManager.shared
    @State private var confirmDelete = false
    @State private var errorText: String?

    private var hiddenJudges: [KSISJudge] { (result.judges ?? []).filter(\.hidden) }
    private var publishedJudges: [KSISJudge] { (result.judges ?? []).filter { !$0.hidden } }

    var body: some View {
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        if let rounds = result.rounds, !rounds.isEmpty {
                            ForEach(rounds) { round in
                                roundCard(round)
                            }
                            judgesLegend
                        } else {
                            noMarksCard
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(result.categoryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zavrieť") { dismiss() }
                        .foregroundColor(Color.gold400)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            open("sutaz.php?sutaz_id=\(result.sutazId)")
                        } label: {
                            Label("Výsledková listina v KSIS", systemImage: "list.number")
                        }
                        Button {
                            open("hodnot_sut.php?sutaz_id=\(result.sutazId)")
                        } label: {
                            Label("Hodnotenie v KSIS", systemImage: "xmark.square")
                        }
                        if isOwn {
                            Button(role: .destructive) {
                                confirmDelete = true
                            } label: {
                                Label("Odstrániť z denníka", systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Color.gold400)
                    }
                    .accessibilityLabel("Možnosti")
                }
            }
            .confirmationDialog("Odstrániť výsledok z denníka?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Odstrániť", role: .destructive) { delete() }
            } message: {
                Text("V KSIS sa nič nezmení. Kedykoľvek ho uložíš znova.")
            }
            .alert("Nepodarilo sa", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(result.eventName)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                Text([KSISBrowserView.displayDate(result.date), result.disciplineTitle].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .foregroundColor(Color.textSecondary)
            }
            HStack(spacing: 10) {
                tile(result.placeLine, caption: "miesto")
                tile("+\(result.pointsEarned)", caption: "body")
                if let total = result.cumulativeStats {
                    tile(total, caption: "spolu po súťaži")
                }
            }
            if let start = result.startNumber, !start.isEmpty {
                Text("Štartové číslo \(start)")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
            }
        }
    }

    private func tile(_ value: String, caption: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundColor(Color.gold300)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.caption2)
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .homeCard(cornerRadius: 16)
    }

    // MARK: Rounds
    private func roundCard(_ round: KSISRound) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: round.round.uppercased(), systemImage: round.isFinal || round.isScores ? "crown.fill" : "xmark.square.fill") {
                if let advanced = round.advanced {
                    Label(advanced ? "Postup" : "Bez postupu", systemImage: advanced ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundColor(advanced ? Color.syncEmerald : Color.latinRed)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    fact(round.isFinal || round.isScores ? "Suma" : "Krížiky", round.sumText)
                    if let place = round.place { fact(round.isFinal || round.isScores ? "Miesto" : "Poradie v kole", place.display) }
                    if let advancedCount = round.advancedCount, !round.isFinal {
                        fact("Postúpilo", "\(advancedCount) z \(round.couplesInRound)")
                    }
                }

                ForEach(round.dances, id: \.dance) { dance in
                    danceRow(dance, isFinal: round.isFinal)
                }

                if let hiddenNote = hiddenNote(for: round) {
                    Label(hiddenNote, systemImage: "eye.slash")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .homeCard(cornerRadius: 18)
        }
    }

    private func fact(_ caption: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundColor(.white)
            Text(caption)
                .font(.caption2)
                .foregroundColor(Color.textSecondary)
        }
    }

    private func danceRow(_ dance: KSISDanceMarks, isFinal: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dance.dance.capitalized)
                    .font(.footnote.weight(.bold))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                if let score = dance.score {
                    Text(KSISRound.scoreText(score))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundColor(Color.gold300)
                } else if let crosses = dance.crosses {
                    Text("\(crosses) z \(dance.marks.count)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundColor(Color.textSecondary)
                }
            }
            // Chips narrow to share the width, so a big panel (13 judges) stays on screen.
            HStack(spacing: 4) {
                ForEach(Array(dance.marks.enumerated()), id: \.offset) { _, mark in
                    markChip(mark, isFinal: isFinal)
                }
            }
        }
    }

    private func markChip(_ mark: KSISJudgeMark, isFinal: Bool) -> some View {
        let isCross = mark.mark == "X"
        let highlighted = isFinal || isCross
        return VStack(spacing: 2) {
            Text(mark.letter ?? "?")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(Color.textSecondary)
            Text(isFinal ? mark.mark : (isCross ? "✕" : "·"))
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundColor(highlighted ? Color.obsidian900 : .white.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: 30, minHeight: 30, maxHeight: 30)
                .background(highlighted ? Color.gold400 : Color.white.opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(markLabel(mark, isFinal: isFinal))
    }

    private func markLabel(_ mark: KSISJudgeMark, isFinal: Bool) -> String {
        let judge = mark.name.map { "Porotca \(mark.letter ?? ""), \($0)" } ?? "Porotca \(mark.letter ?? "")"
        if isFinal { return "\(judge): \(mark.mark). miesto" }
        return "\(judge): \(mark.mark == "X" ? "krížik" : "bez krížika")"
    }

    private func hiddenNote(for round: KSISRound) -> String? {
        // Absolute judging publishes a score per dance, not every judge's mark.
        guard !hiddenJudges.isEmpty, !round.isScores else { return nil }
        let letters = hiddenJudges.map(\.letter).joined(separator: ", ")
        if round.isFinal {
            return "Porotca \(letters) je započítaný vo výsledku finále, KSIS jeho umiestnenia nezverejňuje."
        }
        if let hidden = round.hiddenCrosses {
            return "Porotca \(letters): KSIS jeho krížiky nezverejňuje. V Sume je od neho \(hidden) z \(round.dances.count * hiddenJudges.count)."
        }
        return "Porotca \(letters): KSIS jeho krížiky nezverejňuje, Suma ich obsahuje."
    }

    // MARK: Judges and empty state
    @ViewBuilder
    private var judgesLegend: some View {
        if !publishedJudges.isEmpty || !hiddenJudges.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HomeSectionHeader(title: "POROTCOVIA", systemImage: "person.3.fill")
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(result.judges ?? []) { judge in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(judge.letter)
                                .font(.system(.footnote, design: .rounded).weight(.black))
                                .foregroundColor(Color.obsidian900)
                                .frame(width: 24, height: 24)
                                .background(judge.hidden ? Color.white.opacity(0.3) : Color.gold400, in: Circle())
                            Text(judge.hidden
                                 ? "KSIS meno nezverejňuje"
                                 : [judge.name, judge.city.map { "(\($0))" }].compactMap { $0 }.joined(separator: " "))
                                .font(.footnote)
                                .foregroundColor(.white.opacity(judge.hidden ? 0.5 : 0.85))
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .homeCard(cornerRadius: 18)
            }
        }
    }

    private var noMarksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Krížiky od porotcov ešte nie sú uložené.")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)
            Text("Otvor hodnotenie tejto súťaže v KSIS a ťukni Uložiť krížiky.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.65))
            PrimarySheetButton(title: "Otvoriť hodnotenie", isLoading: false, isEnabled: true) {
                open("hodnot_sut.php?sutaz_id=\(result.sutazId)")
            }
        }
        .padding(16)
        .homeCard(cornerRadius: 20)
    }

    // MARK: Actions
    private func open(_ path: String) {
        guard let url = URL(string: "https://\(KSISBrowserView.host)/\(path)") else { return }
        onOpenKSIS(url)
    }

    private func delete() {
        Task {
            do {
                try await manager.delete(result)
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
        }
    }
}
