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
/// One routine: discipline, name, the real path on the floor and its first figures.
/// The same card is used on Home and in the Canvas tab.
struct RoutineCard: View {
    let routine: Routine
    /// Shows a QR button in the corner (Canvas tab).
    var onShareQR: (() -> Void)? = nil
    let onOpen: () -> Void

    private var orderedNodes: [CanvasNode] {
        routine.canvasNodes.sorted { $0.orderIndex < $1.orderIndex }
    }

    private var isLatin: Bool {
        let category = routine.danceCategory.lowercased()
        return category == "latin" || category == "latina"
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 12) {
                titleRow
                if orderedNodes.count > 1 {
                    RoutinePathThumbnail(points: orderedNodes.map { CGPoint(x: $0.x, y: $0.y) })
                        .frame(height: 72)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .id(routine.id)
                        .accessibilityHidden(true)
                }
                if orderedNodes.isEmpty {
                    Text("Zatiaľ bez figúr – otvor plátno a pridaj prvú.")
                        .font(.caption)
                        .foregroundColor(Color.textSecondary)
                } else {
                    figurePills
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
        .accessibilityHint("Otvorí zostavu na plátne")
    }

    private var titleRow: some View {
        HStack(spacing: 12) {
            Image(systemName: isLatin ? "flame.fill" : "drop.fill")
                .font(.callout.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background((isLatin ? Color.latinCrimson : Color.standardBlue).opacity(0.85), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(routine.name)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(DanceNames.display(routine.danceName)) · \(slovakCount(routine.canvasNodes.count, one: "figúra", few: "figúry", many: "figúr"))")
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color.white.opacity(0.7))
            }

            Spacer(minLength: 8)

            if onShareQR == nil {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundColor(Color.gold400.opacity(0.8))
                    .accessibilityHidden(true)
            } else {
                // Room for the QR button that sits on top of the card.
                Color.clear.frame(width: 40, height: 40)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var figurePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(orderedNodes.prefix(4).enumerated()), id: \.element.id) { index, node in
                    HStack(spacing: 4) {
                        Text("\(index + 1).")
                            .foregroundColor(Color.gold400)
                        Text(node.figureName)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.07), in: Capsule())
                }

                if orderedNodes.count > 4 {
                    Text("+\(orderedNodes.count - 4)")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(Color.gold400)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.gold500.opacity(0.14), in: Capsule())
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
            HomeSectionHeader(title: "NAPOSLEDY UPRAVOVANÉ") {
                Text(routine.updatedAt, format: .relative(presentation: .named))
                    .font(.caption.weight(.medium))
                    .foregroundColor(Color.textSecondary)
            }
            RoutineCard(routine: routine, onOpen: onOpen)
        }
    }
}
