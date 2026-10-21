import SwiftUI
import SwiftData

// MARK: - Shared look of Home sections
extension View {
    /// The one card surface used on Home (notes, last routine): soft glass on the velvet background.
    func homeCard(cornerRadius: CGFloat = 18) -> some View {
        self
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Gold all-caps title with an optional count and a trailing action, e.g. "POZNÁMKY 3 … Všetky ›".
struct HomeSectionHeader<Trailing: View>: View {
    let title: String
    var systemImage: String? = nil
    var count: Int? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color.gold400)
                    .symbolEffect(.bounce, value: count ?? 0)
                    .accessibilityHidden(true)
            }

            Text(title)
                .font(.system(.caption, design: .rounded).weight(.black))
                .foregroundColor(Color.gold400)
                .tracking(1.4)
                .accessibilityAddTraits(.isHeader)

            if let count, count > 0 {
                Text("\(count)")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundColor(Color.obsidian900)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.gold400, in: Capsule())
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 8)
            trailing
        }
    }
}

extension HomeSectionHeader where Trailing == EmptyView {
    init(title: String, systemImage: String? = nil, count: Int? = nil) {
        self.init(title: title, systemImage: systemImage, count: count) { EmptyView() }
    }
}

// MARK: - Rows in a card (Profile, Settings)
/// One row inside a glass card: icon in a tinted circle, title, optional subtitle, badge and value.
struct HomeRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var detail: String? = nil
    var badge: String? = nil
    var tint: Color = Color.gold400
    var isDestructive = false
    var showsChevron = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundColor(isDestructive ? Color.latinRed : tint)
                .frame(width: 36, height: 36)
                .background((isDestructive ? Color.latinRed : tint).opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(isDestructive ? Color.latinRed : .white)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.latinCrimson, in: Capsule())
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.65))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 8)

            if let detail {
                Text(detail)
                    .font(.footnote.weight(.bold))
                    .foregroundColor(Color.gold400)
                    .contentTransition(.numericText())
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color.white.opacity(0.35))
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// Thin line between rows of one card, starting after the icon.
struct HomeRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.leading, 62)
    }
}

/// A titled group of rows in one glass card.
struct HomeRowGroup<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HomeSectionHeader(title: title)
            }
            VStack(spacing: 0) { content }
                .homeCard()
        }
    }
}

// MARK: - Dance choice
/// "Tanec ▾" capsule. The menu is split into Standard and Latin; the chosen dance shows its
/// discipline colour (BRAND_GUIDELINES: blue Standard, crimson Latin). Used on Home and in note detail.
struct DanceMenuCapsule: View {
    @Binding var selection: String?
    /// Shown when nothing is chosen; in a filter nothing chosen means "all dances".
    var emptyTitle = "Tanec"
    var clearTitle = "Bez tanca"

    @Query(sort: \Dance.name) private var dances: [Dance]

    private var selectedDance: Dance? { dances.first { $0.name == selection } }

    var body: some View {
        Menu {
            Section("Štandard") {
                ForEach(ordered.filter { $0.category == "Standard" }) { danceButton($0) }
            }
            Section("Latina") {
                ForEach(ordered.filter { $0.category != "Standard" }) { danceButton($0) }
            }
            if selection != nil {
                Divider()
                Button(role: .destructive) { selection = nil } label: {
                    Label(clearTitle, systemImage: "xmark")
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let dance = selectedDance {
                    Circle()
                        .fill(dance.category == "Standard" ? Color.standardBlue : Color.latinCrimson)
                        .frame(width: 7, height: 7)
                } else {
                    Image(systemName: "music.note")
                }
                Text(selection.map(DanceNames.display) ?? emptyTitle)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
            }
            .font(.footnote.weight(.semibold))
            .foregroundColor(selection == nil ? Color.white.opacity(0.85) : Color.obsidian900)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(selection == nil ? Color.white.opacity(0.08) : Color.gold400, in: Capsule())
            .contentShape(Capsule())
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selection)
        }
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityLabel("Tanec")
        .accessibilityValue(selection.map(DanceNames.display) ?? "nevybraný")
    }

    /// In competition order (Waltz, Tango, …), not alphabetical.
    private var ordered: [Dance] { dances.sorted { DanceNames.rank($0.name) < DanceNames.rank($1.name) } }

    private func danceButton(_ dance: Dance) -> some View {
        Button {
            selection = selection == dance.name ? nil : dance.name
        } label: {
            if selection == dance.name {
                Label(DanceNames.display(dance.name), systemImage: "checkmark")
            } else {
                Text(DanceNames.display(dance.name))
            }
        }
    }
}

// MARK: - Slovak counts
/// Slovak plural: 1 zostava, 2–4 zostavy, 0 and 5+ zostáv.
func slovakCount(_ n: Int, one: String, few: String, many: String) -> String {
    switch n {
    case 1: return "1 \(one)"
    case 2...4: return "\(n) \(few)"
    default: return "\(n) \(many)"
    }
}

// MARK: - Routine card
/// One routine (BRAND_GUIDELINES §1A): name, dance, its length and the figures as a strip in time. Each piece
/// of the strip is as wide as the figure's bars and gold when the figure has a video, so the length and what is
/// still missing show at a glance. The same card is used on Home, in Zostavy and in the profile.
struct RoutineCard: View {
    let routine: Routine
    /// Shows a QR button in the corner (Zostavy tab).
    var onShareQR: (() -> Void)? = nil
    let onOpen: () -> Void

    @Query private var dances: [Dance]

    private var orderedNodes: [CanvasNode] {
        routine.canvasNodes.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var totalBars: Int { routine.barsSummary.bars }

    /// "≈ 1:35" when the figures have bars and the dance has a tempo.
    private var lengthText: String? {
        guard totalBars > 0, let barsPerMinute = dances.barsPerMinute(for: routine.danceName) else { return nil }
        return "≈ " + RoutineTiming.text(RoutineTiming.seconds(bars: totalBars, barsPerMinute: barsPerMinute))
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                titleRow
                if orderedNodes.isEmpty {
                    Text("Zatiaľ bez figúr. Otvor plátno a pridaj prvú.")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                } else {
                    RoutineFigureStrip(nodes: orderedNodes)
                        .frame(height: 22)
                        .id(routine.id)
                    detailRow
                    Text(orderedNodes.map(\.figureName).joined(separator: " → "))
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCard(cornerRadius: 20)
        }
        .buttonStyle(.pressable(scale: 0.97))
        .overlay(alignment: .topTrailing) {
            if let onShareQR {
                LiquidGlassCircleButton(icon: "qrcode", label: "Zdieľať zostavu cez QR kód", size: 40, action: onShareQR)
                    .padding(10)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Otvorí zostavu na plátne")
    }

    private var titleRow: some View {
        HStack(spacing: 12) {
            Image(systemName: routine.isLatin ? "flame.fill" : "drop.fill")
                .font(.callout.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background((routine.isLatin ? Color.latinCrimson : Color.standardBlue).opacity(0.85),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(DanceNames.display(routine.danceName)) · \(routine.isLatin ? "Latina" : "Štandard")")
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color.textSecondary)
            }

            Spacer(minLength: 8)

            if totalBars > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    if let lengthText {
                        Text(lengthText)
                            .font(.system(.headline, design: .rounded).weight(.heavy))
                            .foregroundColor(Color.gold400)
                            .monospacedDigit()
                    }
                    Text(RoutineTiming.barsText(totalBars))
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color.textSecondary)
                }
            }

            if onShareQR != nil {
                // Room for the QR button that sits on top of the card.
                Color.clear.frame(width: 40, height: 40)
            }
        }
    }

    private var detailRow: some View {
        let withVideo = orderedNodes.filter { $0.displayVideoPath != nil }.count
        return HStack {
            // "nahraté", not "s videom": beside "23 s" that read as seconds.
            Text("\(slovakCount(orderedNodes.count, one: "figúra", few: "figúry", many: "figúr")) · \(withVideo) nahraté")
            Spacer(minLength: 8)
            Text(routine.updatedAt, format: .relative(presentation: .named))
        }
        .font(.caption2.weight(.medium))
        .foregroundColor(Color.textSecondary)
    }

    private var accessibilityText: String {
        var parts = [routine.name, DanceNames.display(routine.danceName),
                     slovakCount(orderedNodes.count, one: "figúra", few: "figúry", many: "figúr")]
        if let lengthText { parts.append("dĺžka \(lengthText.replacingOccurrences(of: "≈ ", with: "približne "))") }
        return parts.joined(separator: ", ")
    }
}

/// The routine as a strip in time: one piece per figure, as wide as its bars (figures without bars get the
/// average), gold with a video and muted without; the number shows where it fits.
struct RoutineFigureStrip: View {
    let nodes: [CanvasNode]

    private var widths: [Double] {
        let known = nodes.compactMap(\.bars)
        let fallback = known.isEmpty ? 1 : Double(known.reduce(0, +)) / Double(known.count)
        return nodes.map { $0.bars.map(Double.init) ?? fallback }
    }

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 3
            let total = widths.reduce(0, +)
            let free = max(0, geo.size.width - spacing * CGFloat(nodes.count - 1))
            HStack(spacing: spacing) {
                ForEach(Array(zip(nodes, widths).enumerated()), id: \.element.0.id) { index, item in
                    let width = free * CGFloat(item.1 / max(total, 1))
                    let hasVideo = item.0.displayVideoPath != nil
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(hasVideo ? Color.gold400 : Color.gold500.opacity(0.22))
                        .frame(width: width)
                        .overlay {
                            if width >= 16 {
                                Text("\(index + 1)")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundColor(hasVideo ? Color.obsidian900 : Color.gold300)
                            }
                        }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Last edited routine (Home)
struct HomeRecentRoutineCard: View {
    let routine: Routine
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeSectionHeader(title: "NAPOSLEDY UPRAVOVANÉ")
            RoutineCard(routine: routine, onOpen: onOpen)
        }
    }
}
