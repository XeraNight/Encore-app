import SwiftData
import SwiftUI

// MARK: - Súťažný deň (Plus)
/// On competition day one calm screen: the dances in competition order and, at each, the open Top 3 from the
/// coach, read in ten seconds before a round. Only dances with something to remember are shown (which dances a
/// class dances is not invented here). The dance with the fewest crosses this season gets a quiet mark.
/// The screen stays on while it is open.
struct CompetitionDayView: View {
    let competition: PlannedCompetition

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \LessonPriority.createdAt, order: .reverse) private var priorities: [LessonPriority]
    @ObservedObject private var results = CompetitionManager.shared
    @State private var appeared = false

    var body: some View {
        let plan = CompetitionDayPlan(competition: competition, priorities: priorities, results: results.results)
        NavigationStack {
            ZStack {
                EllegancePageBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        if plan.dances.isEmpty {
                            emptyCard
                        } else {
                            ForEach(Array(plan.dances.enumerated()), id: \.element.id) { index, dance in
                                danceCard(dance, isWeakest: dance.danceName == plan.weakestDance)
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 18)
                                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85)
                                        .delay(Double(index) * 0.06), value: appeared)
                            }
                            if !plan.otherDances.isEmpty {
                                Text("Bez priorít: \(plan.otherDances.map(DanceNames.display).joined(separator: ", ")).")
                                    .font(.footnote)
                                    .foregroundColor(Color.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Súťažný deň")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zavrieť") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
        .task { if results.results.isEmpty { await results.loadAllData() } }
        .onAppear {
            // Read between rounds without touching the phone.
            UIApplication.shared.isIdleTimerDisabled = true
            appeared = true
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(PlannerCalendar.daysText(until: competition.date).uppercased())
                .font(.system(.caption, design: .rounded).weight(.black))
                .tracking(1.4)
                .foregroundColor(Color.gold400)
            Text(competition.name)
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundColor(.white)
            if !competition.city.isEmpty || !competition.targetCategories.isEmpty {
                Text(([competition.city] + competition.targetCategories).filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.65))
            }
        }
        .padding(.bottom, 4)
    }

    private func danceCard(_ dance: CompetitionDayPlan.Dance, isWeakest: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(DanceNames.display(dance.danceName))
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundColor(.white)
                Spacer()
                if isWeakest {
                    Label("najmenej krížikov", systemImage: "target")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(Color.latinRed)
                        .accessibilityLabel("V tomto tanci dostávaš v sezóne najmenej krížikov")
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(dance.priorities.enumerated()), id: \.offset) { index, text in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(.subheadline, design: .rounded).weight(.black))
                            .foregroundColor(Color.obsidian900)
                            .frame(width: 26, height: 26)
                            .background(Color.gold400, in: Circle())
                        Text(text)
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 22)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isWeakest ? Color.latinRed.opacity(0.45) : Color.clear, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zatiaľ tu nič nie je")
                .font(.headline)
                .foregroundColor(.white)
            Text("Po lekcii si zapíš Top 3 korekcie pre tanec. V deň súťaže ich tu uvidíš pri každom tanci v poradí, v akom sa tancujú.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard(cornerRadius: 22)
    }
}

/// What the competition-day screen shows, worked out from the dancer's own data.
struct CompetitionDayPlan {
    struct Dance: Identifiable {
        let danceName: String
        let priorities: [String]
        var id: String { danceName }
    }

    /// Dances of the competition's discipline that have open Top 3 items, in competition order.
    let dances: [Dance]
    /// The other dances of the discipline, without priorities.
    let otherDances: [String]
    /// The dance with the fewest crosses in the current season, when Moja sezóna can tell.
    let weakestDance: String?

    init(competition: PlannedCompetition, priorities: [LessonPriority], results: [CompetitionResult]) {
        let discipline = PlannerDisciplineChoice.competitionValue(from: competition.targetCategories)
        let standard = Array(DanceNames.order.prefix(5)), latin = Array(DanceNames.order.suffix(5))
        let ordered: [String] = switch discipline {
        case "Latina": latin
        case "Obe": standard + latin
        default: standard
        }
        let sets = LessonPriorities.activeSets(priorities)
        var dances: [Dance] = []
        var others: [String] = []
        for name in ordered {
            // The newest Top 3 of the dance, only what is still open.
            let open = sets.first { $0.danceName == name }?.items.filter(\.isOpen).map(\.text) ?? []
            if open.isEmpty { others.append(name) } else { dances.append(Dance(danceName: name, priorities: open)) }
        }
        self.dances = dances
        otherDances = others

        let season = SeasonStats(results: results, seasonStartYear: SeasonStats.seasonStartYear(of: competition.date))
        let rated = season.disciplines.flatMap(\.dances).filter { ordered.contains($0.dance) }
        weakestDance = season.disciplines.compactMap(\.weakest).first { rated.contains($0) }?.dance
    }
}
