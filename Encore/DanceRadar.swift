import SwiftUI

// MARK: - Ako mi idú tance
/// One value per dance (0…1) for the first half of the season and for the second half up to today, so the two
/// shapes show progress. Every value is counted from the dancer's own records; nothing is estimated.
struct DanceRadar: Equatable {
    enum Metric: String, CaseIterable, Identifiable {
        case training, feelings, corrections, competitions
        var id: String { rawValue }

        var title: String {
            switch self {
            case .training: return "Tréning"
            case .feelings: return "Pocity"
            case .corrections: return "Korekcie"
            case .competitions: return "Súťaže"
            }
        }

        var explanation: String {
            switch self {
            case .training: return "Koľkokrát si tanec zapísal v reflexii po tréningu."
            case .feelings: return "Skvelé pocity a prelomy oproti únave, z poznámok Ako to bolo."
            case .corrections: return "Koľko korekcií z Top 3 od trénera si zvládol."
            case .competitions: return "Podiel krížikov od porotcov v súťažiach z KSIS."
            }
        }
    }

    enum Discipline: String, CaseIterable, Identifiable {
        case standard, latin
        var id: String { rawValue }
        var title: String { self == .standard ? "ŠTT" : "LAT" }
        /// Dances as Encore stores them, in the order KSIS dances them.
        var dances: [String] { self == .standard ? Array(DanceNames.order.prefix(5)) : Array(DanceNames.order.suffix(5)) }
        var ksisCode: String { self == .standard ? "STT" : "LAT" }
    }

    let dances: [String]
    /// nil where the dance has no record in that half.
    let before: [Double?]
    let now: [Double?]

    var hasData: Bool { (before + now).contains { $0 != nil } }

    static func make(_ metric: Metric, _ discipline: Discipline, logs: [TrainingLogEntry], priorities: [LessonPriority],
                     results: [CompetitionResult], today: Date = Date()) -> DanceRadar {
        let start = PlannerCalendar.seasonStart(of: today)
        let middle = start.addingTimeInterval(today.timeIntervalSince(start) / 2)
        let halves = [start..<middle, middle..<today.addingTimeInterval(1)]
        let dances = discipline.dances

        let values: [[Double?]]
        switch metric {
        case .training:
            // Normalised by the busiest dance in either half, so the halves compare.
            let counts = halves.map { half in
                dances.map { dance in logs.filter { half.contains($0.day) && Self.names(in: $0).contains(dance) }.count }
            }
            let most = counts.flatMap { $0 }.max() ?? 0
            values = counts.map { row in row.map { most > 0 ? Double($0) / Double(most) : nil } }
        case .feelings:
            values = halves.map { half in
                let moments = logs.filter { half.contains($0.day) }.flatMap(\.moments)
                return dances.map { dance in
                    let mine = moments.filter { $0.danceName == dance }
                    let good = mine.filter { $0.feeling == .great || $0.feeling == .breakthrough }.count
                    let tired = mine.filter { $0.feeling == .tired }.count
                    // −1 (only tiredness) … +1 (only good moments), drawn as 0 … 1.
                    return good + tired > 0 ? (Double(good - tired) / Double(good + tired) + 1) / 2 : nil
                }
            }
        case .corrections:
            values = halves.map { half in
                dances.map { dance in
                    let set = priorities.filter { $0.danceName == dance && half.contains($0.createdAt) }
                    return set.isEmpty ? nil : Double(set.filter { $0.doneAt != nil }.count) / Double(set.count)
                }
            }
        case .competitions:
            let year = SeasonStats.seasonStartYear(of: today)
            values = halves.map { half in
                let rates = SeasonStats(results: results.filter { $0.dateValue.map(half.contains) == true }, seasonStartYear: year)
                    .disciplines.first { $0.code == discipline.ksisCode }?.dances ?? []
                return dances.map { dance in rates.first { $0.dance == dance }?.rate }
            }
        }
        return DanceRadar(dances: dances, before: values[0], now: values[1])
    }

    /// The dances a reflection names: the training's dance and the dance of each feeling.
    private static func names(in log: TrainingLogEntry) -> Set<String> {
        Set([log.danceName].compactMap { $0 } + log.moments.compactMap(\.danceName))
    }
}

// MARK: - Radar
struct DanceRadarChart: View {
    let radar: DanceRadar

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 38
            ZStack {
                ForEach(1...4, id: \.self) { ring in
                    outline(Array(repeating: Double(ring) / 4, count: radar.dances.count), center, radius)
                        .stroke(Color.white.opacity(ring == 4 ? 0.18 : 0.08), lineWidth: 1)
                }
                Path { path in
                    for index in radar.dances.indices {
                        path.move(to: center)
                        path.addLine(to: point(index, 1, center, radius))
                    }
                }
                .stroke(Color.white.opacity(0.08), lineWidth: 1)

                let before = radar.before.map { $0 ?? 0 }
                outline(before, center, radius).fill(Color.white.opacity(0.08))
                outline(before, center, radius).stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                let now = radar.now.map { $0 ?? 0 }
                outline(now, center, radius).fill(Color.gold400.opacity(0.28))
                outline(now, center, radius).stroke(Color.gold400, lineWidth: 2)
                ForEach(radar.dances.indices, id: \.self) { index in
                    Circle()
                        .fill(Color.gold400)
                        .frame(width: 6, height: 6)
                        .position(point(index, now[index], center, radius))
                }

                ForEach(radar.dances.indices, id: \.self) { index in
                    Text(DanceNames.display(radar.dances[index]))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize()
                        .position(point(index, 1.24, center, radius))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    /// The first dance at the top, the rest clockwise.
    private func point(_ index: Int, _ value: Double, _ center: CGPoint, _ radius: CGFloat) -> CGPoint {
        let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(max(radar.dances.count, 1))
        return CGPoint(x: center.x + CGFloat(cos(angle) * value) * radius, y: center.y + CGFloat(sin(angle) * value) * radius)
    }

    private func outline(_ values: [Double], _ center: CGPoint, _ radius: CGFloat) -> Path {
        Path { path in
            for (index, value) in values.enumerated() {
                let target = point(index, min(max(value, 0), 1), center, radius)
                if index == 0 { path.move(to: target) } else { path.addLine(to: target) }
            }
            path.closeSubpath()
        }
    }

    private var accessibilityText: String {
        radar.dances.indices.map { index in
            let now = radar.now[index].map { "\(Int(($0 * 100).rounded())) %" } ?? "bez údajov"
            return "\(DanceNames.display(radar.dances[index])): \(now)"
        }.joined(separator: ", ")
    }
}

// MARK: - Section in Vývoj
struct DanceRadarSection: View {
    let logs: [TrainingLogEntry]
    let priorities: [LessonPriority]

    @ObservedObject private var competitions = CompetitionManager.shared
    @State private var metric: DanceRadar.Metric = .training
    @State private var discipline: DanceRadar.Discipline = .standard

    var body: some View {
        let radar = DanceRadar.make(metric, discipline, logs: logs, priorities: priorities, results: competitions.results)
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: "AKO MI IDÚ TANCE", systemImage: "pentagon")
            VStack(alignment: .leading, spacing: 12) {
                PlannerChoice(options: DanceRadar.Discipline.allCases.map { ($0, $0.title) }, selection: $discipline)
                PlannerChoice(options: DanceRadar.Metric.allCases.map { ($0, $0.title) }, selection: $metric)
                if radar.hasData {
                    DanceRadarChart(radar: radar)
                        .id("\(metric.rawValue).\(discipline.rawValue)")
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    HStack(spacing: 16) {
                        legend("Začiatok sezóny", color: .white.opacity(0.55), dashed: true)
                        legend("Teraz", color: Color.gold400, dashed: false)
                    }
                } else {
                    Text(emptyText)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 8)
                }
                Text(metric.explanation)
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .homeCard(cornerRadius: 20)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: radar)
        }
        .sensoryFeedback(.selection, trigger: metric)
        .sensoryFeedback(.selection, trigger: discipline)
        .task(id: metric) {
            // KSIS results only when that view is chosen and they are not loaded yet.
            if metric == .competitions && competitions.results.isEmpty { await competitions.loadAllData() }
        }
    }

    private var emptyText: String {
        switch metric {
        case .training: return "Pri reflexii po tréningu vyber tanec a tvar sa tu začne kresliť."
        case .feelings: return "V Ako to bolo pridaj k pocitom aj tanec."
        case .corrections: return "Po lekcii zapíš k tancu Top 3 korekcie od trénera."
        case .competitions: return "V Súťažiach ulož krížiky porotcov zo súťaží tejto sezóny."
        }
    }

    private func legend(_ title: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [3, 3] : []))
                .frame(width: 18, height: 2)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}
