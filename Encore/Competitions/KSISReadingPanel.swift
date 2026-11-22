import SwiftUI

/// What the KSIS window says while the update reads: a light that runs, what is being read, how far it is, and why
/// it takes a while.
struct KSISReadingPanel: View {
    let label: String
    let progress: KSISReadingProgress
    let stages: [KSISReadingProgress.Stage]
    /// The page being read is taking long.
    var isSlow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                InfinityLoopView(width: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sťahujem z KSIS")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundColor(.white)
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color.gold300)
                        .lineLimit(2)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: label)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 5) {
                ForEach(stages, id: \.self) { stage in
                    bar(for: stage)
                }
            }

            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                Text(caption(now: timeline.date))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .monospacedDigit()
            }

            if isSlow {
                Label("KSIS odpovedá pomaly. Čakám ďalej, nič sa nestratí.", systemImage: "hourglass")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color.gold400)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Appka otvára stránky KSIS jednu po druhej, tak ako by ich otvoril človek. Preto to chvíľu trvá. Nechaj túto obrazovku otvorenú.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// One step: full when it is behind, as full as it is read when it is the current one.
    private func bar(for stage: KSISReadingProgress.Stage) -> some View {
        let order = stages.firstIndex(of: stage) ?? 0
        let current = stages.firstIndex(of: progress.stage) ?? 0
        let filled: Double = order < current ? 1 : (order == current ? (progress.fraction ?? 0) : 0)
        return Capsule()
            .fill(Color.white.opacity(0.14))
            .frame(height: 5)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(LinearGradient(colors: [Color.gold500, Color.gold400], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(order == current ? 6 : 0, proxy.size.width * filled))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: filled)
    }

    private func caption(now: Date) -> String {
        var parts: [String] = []
        if stages.count > 1, let index = stages.firstIndex(of: progress.stage) {
            parts.append("Krok \(index + 1) z \(stages.count)")
        }
        parts.append(progress.stage.title)
        if let left = progress.secondsLeft(now: now) {
            parts.append("zostáva \(KSISReadingProgress.waitText(left))")
        }
        return parts.joined(separator: " · ")
    }
}
