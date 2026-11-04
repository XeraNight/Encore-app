import SwiftUI
import SwiftData

// MARK: - Canvas Grid Background
struct CanvasGridBackground: View {
    let roomSize: CGFloat
    var body: some View {
        Path { path in
            let step: CGFloat = 80
            for x in stride(from: 0, to: roomSize, by: step) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: roomSize))
            }
            for y in stride(from: 0, to: roomSize, by: step) {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: roomSize, y: y))
            }
        }
        .stroke(Color.themeBorder.opacity(0.6), lineWidth: 1)
    }
}

// MARK: - Ballroom Floor Geometry Configuration
public struct BallroomFloorConfig {
    public static let canvasSize: CGFloat = 3000
    public static let centerPoint: CGPoint = CGPoint(x: 1500, y: 1500)
    
    // Proportional Ballroom Floor (Standard 2:3 ratio)
    // Vertical long sides align naturally with iPhone portrait orientation (sides of screen)
    public static let floorWidth: CGFloat = 840   // Krátke steny (hore a dole)
    public static let floorHeight: CGFloat = 1260 // Dlhé steny (ľavá a pravá strana iPhonu)
    public static let cornerRadius: CGFloat = 26
    
    // Safe bounds inside the ballroom floor so cards never overlap or leave the golden walls
    public static func safeCardBounds(
        cardWidth: CGFloat = 140,
        cardHeight: CGFloat = 132,
        wallMargin: CGFloat = 18
    ) -> (minX: Double, maxX: Double, minY: Double, maxY: Double) {
        let minX = (centerPoint.x - floorWidth / 2.0) + (cardWidth / 2.0) + wallMargin
        let maxX = (centerPoint.x + floorWidth / 2.0) - (cardWidth / 2.0) - wallMargin
        let minY = (centerPoint.y - floorHeight / 2.0) + (cardHeight / 2.0) + wallMargin
        let maxY = (centerPoint.y + floorHeight / 2.0) - (cardHeight / 2.0) - wallMargin
        return (Double(minX), Double(maxX), Double(minY), Double(maxY))
    }
}

// MARK: - 0. Ballroom Real Wood Parquet Floor (Competition Dance Floor)
struct DanceParquetFloorView: View {
    let roomSize: CGFloat
    
    let width: CGFloat = BallroomFloorConfig.floorWidth
    let height: CGFloat = BallroomFloorConfig.floorHeight
    let cornerRadius: CGFloat = BallroomFloorConfig.cornerRadius
    
    var body: some View {
        ZStack {
            // 0. Solid Warm Oak Wood Parquet Foundation (Guarantees immediate visibility)
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.38, green: 0.24, blue: 0.14),
                            Color(red: 0.26, green: 0.16, blue: 0.09),
                            Color(red: 0.18, green: 0.10, blue: 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: width, height: height)
                .shadow(color: Color.black.opacity(0.85), radius: 36, x: 0, y: 18)
                .shadow(color: Color.black.opacity(0.60), radius: 14, x: 0, y: 6)
            
            // 1. Real Oak Wood Parquet Floor Tile
            Image("DanceParquetFloor")
                .resizable(resizingMode: .stretch)
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            
            // 2. Amber Satin Varnish Reflection & Spotlight Depth
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.amberGold.opacity(0.12),
                            Color.clear,
                            Color.black.opacity(0.25)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .frame(width: width, height: height)
        }
        .position(x: roomSize / 2, y: roomSize / 2)
    }
}

// MARK: - Ballroom Markings & Golden Wall Definitions (Dlhé & Krátke Steny)
struct BallroomMarkingsView: View {
    let roomSize: CGFloat
    
    let width: CGFloat = BallroomFloorConfig.floorWidth
    let height: CGFloat = BallroomFloorConfig.floorHeight
    let cornerRadius: CGFloat = BallroomFloorConfig.cornerRadius
    
    var body: some View {
        ZStack {
            // ── 1. Luxusný Zlatý Lem okolo celého obvodu parketu (Zlatý Border) ──
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.gold300,
                            Color.gold400,
                            Color.gold500,
                            Color.amberGold,
                            Color.gold300
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 5.0
                )
                .frame(width: width, height: height)
                .shadow(color: Color.gold400.opacity(0.85), radius: 16)
            
            // Vnútorná zlatá jemná lišta
            RoundedRectangle(cornerRadius: cornerRadius - 5)
                .stroke(Color.gold400.opacity(0.40), lineWidth: 1.5)
                .frame(width: width - 18, height: height - 18)
            
            // ── 2. DLHÉ STENY (Long Sides - Strany iPhonu: Ľavá a Pravá) ──
            // Ľavá stena: Výrazná hrubá zlatá lišta pozdĺž celej výšky
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.gold300, Color.gold400, Color.gold500],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6, height: height - 80)
                .offset(x: -width / 2 + 3)
                .shadow(color: Color.gold400.opacity(0.95), radius: 12)
            
            // Pravá stena: Výrazná hrubá zlatá lišta pozdĺž celej výšky
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.gold300, Color.gold400, Color.gold500],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 6, height: height - 80)
                .offset(x: width / 2 - 3)
                .shadow(color: Color.gold400.opacity(0.95), radius: 12)
            
            // Line of dance runs counter-clockwise around the floor (seen from above): down the left wall,
            // along the bottom to the right, up the right wall, along the top to the left.
            // The long-wall badges are turned -90°, so "arrow.left" in the badge points down on screen.
            wallBadge(
                title: "DLHÁ STENA",
                subTitle: "SMER TANCA",
                icon: "arrow.left",
                isVertical: true
            )
            .offset(x: -width / 2 + 42)
            
            // Right long wall: up on screen ("arrow.right" in the turned badge)
            wallBadge(
                title: "DLHÁ STENA",
                subTitle: "SMER TANCA",
                icon: "arrow.right",
                isVertical: true
            )
            .offset(x: width / 2 - 42)
            
            // ── 3. KRÁTKE STENY (Short Sides - Hore a Dole na iPhone) ──
            // Horná stena: Zlatá lišta
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.gold300, Color.gold400, Color.gold500],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width - 80, height: 5)
                .offset(y: -height / 2 + 2.5)
                .shadow(color: Color.gold400.opacity(0.80), radius: 8)
            
            // Dolná stena: Zlatá lišta
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.gold300, Color.gold400, Color.gold500],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width - 80, height: 5)
                .offset(y: height / 2 - 2.5)
                .shadow(color: Color.gold400.opacity(0.80), radius: 8)
            
            // Top short wall: to the left
            wallBadge(
                title: "KRÁTKA STENA",
                subTitle: "SMER TANCA",
                icon: "arrow.left",
                isVertical: false
            )
            .offset(y: -height / 2 + 36)
            
            // Bottom short wall: to the right
            wallBadge(
                title: "KRÁTKA STENA",
                subTitle: "SMER TANCA",
                icon: "arrow.right",
                isVertical: false
            )
            .offset(y: height / 2 - 36)
            
            // ── 4. STRED PARKETU (Ballroom Center Compass Rose) ──
            centerCompassRose
        }
        .position(x: roomSize / 2, y: roomSize / 2)
    }
    
    // MARK: - Wall Identification Badge with LOD Direction Arrow
    private func wallBadge(title: String, subTitle: String, icon: String, isVertical: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundColor(Color.gold300)
            
            VStack(alignment: isVertical ? .center : .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1.8)
                
                Text(subTitle)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(Color.gold400)
                    .tracking(1.0)
            }
            
            Image(systemName: icon)
                .font(.system(size: 13, weight: .black))
                .foregroundColor(Color.gold300)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.obsidian900.opacity(0.94))
                .overlay(
                    Capsule()
                        .stroke(
                            LinearGradient(
                                colors: [Color.gold300, Color.gold500, Color.gold400],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.6
                        )
                )
                .shadow(color: Color.gold500.opacity(0.50), radius: 10)
        )
        .rotationEffect(.degrees(isVertical ? -90 : 0))
    }
    
    // MARK: - Center Ballroom Compass
    private var centerCompassRose: some View {
        ZStack {
            // Outer golden boundary ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.gold400.opacity(0.60), Color.gold500.opacity(0.20), Color.gold400.opacity(0.60)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 220, height: 220)
            
            // Inset dashed ring
            Circle()
                .stroke(Color.gold400.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .frame(width: 190, height: 190)
            
            // Center crosshair lines
            Path { p in
                p.move(to: CGPoint(x: -110, y: 0))
                p.addLine(to: CGPoint(x: 110, y: 0))
                p.move(to: CGPoint(x: 0, y: -110))
                p.addLine(to: CGPoint(x: 0, y: 110))
            }
            .stroke(Color.gold400.opacity(0.20), lineWidth: 1)
            
            // A quiet floor marking: figures placed in the middle cover it, as on a real floor.
            Text("STRED")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(2.2)
                .foregroundColor(Color.gold400.opacity(0.55))
                .offset(y: 16)
        }
        .accessibilityHidden(true)
    }
}


// MARK: - Connections Layer
struct ConnectionsLayer: View {
    let nodes: [CanvasNode]
    var livePositions: [UUID: CGPoint] = [:]
    /// Current zoom: the transition buttons keep a 44 pt touch area on screen at any zoom.
    var scale: CGFloat = 1
    var onConnectionTap: (CanvasNode, CanvasNode) -> Void
    
    private func pos(for node: CanvasNode) -> CGPoint {
        livePositions[node.id] ?? CGPoint(x: node.x, y: node.y)
    }
    
    var body: some View {
        let sorted = nodes.sorted(by: { $0.orderIndex < $1.orderIndex })
        ZStack {
            // GPU-accelerated Metal stroke layer
            ZStack {
                ForEach(0..<sorted.count, id: \.self) { idx in
                    if idx > 0 {
                        let prev = sorted[idx - 1]
                        let curr = sorted[idx]
                        let p1 = pos(for: prev)
                        let p2 = pos(for: curr)
                        
                        ConnectionLineShape(from: p1, to: p2)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.gold500.opacity(0.6), Color.gold400.opacity(0.2)],
                                    startPoint: .init(x: 0, y: 0),
                                    endPoint: .init(x: 1, y: 1)
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 4])
                            )
                    }
                }
            }
            .allowsHitTesting(false)
            
            // Interactive connection buttons overlay
            ForEach(0..<sorted.count, id: \.self) { idx in
                if idx > 0 {
                    let prev = sorted[idx - 1]
                    let curr = sorted[idx]
                    let p1 = pos(for: prev)
                    let p2 = pos(for: curr)
                    let centerPoint = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
                    Button(action: { onConnectionTap(prev, curr) }) {
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.themeAccent)
                                .background(Color.themeCard.clipShape(Circle()))
                                .frame(width: 44 / max(scale, 0.1), height: 44 / max(scale, 0.1))
                                .contentShape(Circle())
                            if !curr.transitionNotes.isEmpty {
                                Text(curr.transitionNotes)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.themeAccent)
                                    .cornerRadius(6)
                                    .shadow(color: Color.themeDark.opacity(0.05), radius: 2)
                            }
                        }
                    }
                    .buttonStyle(.pressable(scale: 0.9))
                    .accessibilityLabel("Prechod z \(prev.figureName) do \(curr.figureName)")
                    .position(centerPoint)
                }
            }
        }
    }
}

struct ConnectionLineShape: Shape {
    var from: CGPoint
    var to: CGPoint
    
    var animatableData: AnimatablePair<CGPoint.AnimatableData, CGPoint.AnimatableData> {
        get { AnimatablePair(from.animatableData, to.animatableData) }
        set { from.animatableData = newValue.first; to.animatableData = newValue.second }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        let (control1, control2) = Self.controls(from: from, to: to)
        path.addCurve(to: to, control1: control1, control2: control2)
        return path
    }

    /// Across first, then along: the curve every line on the floor follows.
    private static func controls(from: CGPoint, to: CGPoint) -> (CGPoint, CGPoint) {
        let middleX = from.x + (to.x - from.x) * 0.5
        return (CGPoint(x: middleX, y: from.y), CGPoint(x: middleX, y: to.y))
    }

    /// Points along the curve, so figure names can keep off it (`CanvasLabelLayout`).
    static func samples(from: CGPoint, to: CGPoint, count: Int = 8) -> [CGPoint] {
        let (control1, control2) = controls(from: from, to: to)
        return (0...count).map { step in
            let t = CGFloat(step) / CGFloat(count), u = 1 - t
            let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
            return CGPoint(
                x: a * from.x + b * control1.x + c * control2.x + d * to.x,
                y: a * from.y + b * control1.y + c * control2.y + d * to.y
            )
        }
    }
}

// MARK: - Canvas Node Card View
struct CanvasNodeCardView: View {
    @Bindable var node: CanvasNode
    /// Position in the routine as shown (1-based); a figure waiting to be deleted is left out.
    var number: Int? = nil
    let scale: CGFloat
    var cardScale: CGFloat = 1.0
    /// Where the name goes from the circle's centre, in screen points (`CanvasLabelLayout`); nil when it has no room.
    var labelOffset: CGPoint? = nil
    var lockedByUserName: String? = nil
    var onTap: () -> Void
    var onDelete: () -> Void
    var onDrag: ((Double, Double) -> Void)? = nil
    var onDragStart: (() -> Void)? = nil
    var onDragEnd: ((Double, Double) -> Void)? = nil
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    private var isLockedByPartner: Bool {
        lockedByUserName != nil
    }

    /// The pin keeps its size at any zoom, like a place on a map, so the floor stays visible; the figure size
    /// menu changes only the circle.
    private var circleSize: CGFloat { CanvasLabelLayout.circleSize * cardScale }
    /// Undoes the canvas zoom, so the pin is drawn in screen points.
    private var pinScale: CGFloat { 1 / max(scale, 0.05) }

    var body: some View {
        pin
            .scaleEffect(pinScale)
            .scaleEffect(isDragging ? 1.12 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
            .onTapGesture(perform: onTap)
            .contextMenu {
                Button(action: onTap) { Label("Otvoriť figúru", systemImage: "arrow.up.right.square") }
                if !isLockedByPartner {
                    // The canvas asks first, in the middle of the screen.
                    Button(role: .destructive, action: onDelete) { Label("Vymazať figúru", systemImage: "trash") }
                }
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .global)
                    .onChanged { value in
                        guard !isLockedByPartner else { return }
                        if !isDragging {
                            isDragging = true
                            onDragStart?()
                        }
                        let live = clampedPosition(for: value.translation)
                        dragOffset = CGSize(width: live.x - node.x, height: live.y - node.y)
                        onDrag?(live.x, live.y)
                    }
                    .onEnded { value in
                        guard !isLockedByPartner else { return }
                        let bounds = pinBounds
                        let final = clampedPosition(for: value.translation)
                        // Magnetic snap to the 20 pt floor grid, never past the walls.
                        let snappedX = min(max((final.x / 20.0).rounded() * 20.0, bounds.minX), bounds.maxX)
                        let snappedY = min(max((final.y / 20.0).rounded() * 20.0, bounds.minY), bounds.maxY)
                        node.x = snappedX
                        node.y = snappedY
                        dragOffset = .zero
                        isDragging = false
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        // The canvas saves, syncs and tells the partner (once).
                        onDragEnd?(snappedX, snappedY)
                    }
            )
            .position(x: node.x + dragOffset.width, y: node.y + dragOffset.height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
            .accessibilityHint("Otvorí figúru")
            .accessibilityAddTraits(.isButton)
    }

    /// The circle stays inside the walls (in floor points, whatever the zoom).
    private var pinBounds: (minX: Double, maxX: Double, minY: Double, maxY: Double) {
        let size = circleSize * pinScale
        return BallroomFloorConfig.safeCardBounds(cardWidth: size, cardHeight: size, wallMargin: 8)
    }

    private func clampedPosition(for translation: CGSize) -> (x: Double, y: Double) {
        let bounds = pinBounds
        let x = node.x + translation.width / scale
        let y = node.y + translation.height / scale
        return (min(max(x, bounds.minX), bounds.maxX), min(max(y, bounds.minY), bounds.maxY))
    }

    private var accessibilityText: String {
        var parts = ["Figúra \(number ?? node.orderIndex + 1)", node.figureName]
        if let bars = node.bars { parts.append(RoutineTiming.barsText(bars)) }
        if let lockedBy = lockedByUserName { parts.append("práve ju posúva \(lockedBy)") }
        return parts.joined(separator: ", ")
    }
}

extension CanvasNodeCardView {
    /// The circle exactly on the figure's spot, its name on the side `CanvasLabelLayout` picked. A name without
    /// room fades out and comes back when a pinch makes room.
    fileprivate var pin: some View {
        circle
            .overlay {
                label
                    .frame(width: labelSize.width, height: labelSize.height, alignment: labelAlignment)
                    .offset(x: labelOffset?.x ?? 0, y: labelOffset?.y ?? 0)
                    .opacity(labelOffset == nil ? 0 : 1)
                    .allowsHitTesting(labelOffset != nil)
                    .animation(.easeOut(duration: 0.2), value: labelOffset)
            }
    }

    /// A frame of the figure's video, or Encore crimson; the figure's number in the middle, gold ring.
    fileprivate var circle: some View {
        ZStack {
            if let video = node.displayVideoPath {
                MediaThumbnailView(path: video, cornerRadius: 0, showsFormatBadge: false)
                    .overlay(Color.black.opacity(0.35))
            } else {
                // One routine is one dance, so the floor needs no dance colours.
                Color.encoreCrimsonLight
            }
            Text("\(number ?? node.orderIndex + 1)")
                .font(.system(size: 13 * cardScale, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
        }
        .frame(width: circleSize, height: circleSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(isLockedByPartner ? Color.white : Color.gold400, lineWidth: 2))
        .shadow(color: Color.black.opacity(0.45), radius: 6, y: 3)
        .overlay(alignment: .topTrailing) {
            if let remark = node.coachNotes, !remark.isEmpty {
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.obsidian900)
                    .padding(3)
                    .background(Color.gold400, in: Circle())
                    .offset(x: 5, y: -5)
            }
        }
    }

    /// Dark text straight on the parquet; the light halo keeps it readable where a line runs under it.
    fileprivate var label: some View {
        Group {
            if let lockedBy = lockedByUserName {
                Label(lockedBy, systemImage: "lock.fill")
            } else {
                Text(labelText)
            }
        }
        .font(Font(CanvasLabelLayout.font as CTFont))
        .foregroundStyle(Color.obsidian900)
        .multilineTextAlignment(labelTextAlignment)
        .lineLimit(CanvasLabelLayout.maxLines)
        .truncationMode(.tail)
        .shadow(color: Color.white.opacity(0.85), radius: 1.5)
    }

    fileprivate var labelText: String { CanvasLabelLayout.text(name: node.figureName, bars: node.bars) }
    fileprivate var labelSize: CGSize { CanvasLabelLayout.size(of: labelText) }

    /// A name to the right of the circle starts at it, one to the left ends at it, one above or below is centred.
    fileprivate var labelTextAlignment: TextAlignment {
        guard let x = labelOffset?.x, x != 0 else { return .center }
        return x > 0 ? .leading : .trailing
    }

    fileprivate var labelAlignment: Alignment {
        switch labelTextAlignment {
        case .leading: return .leading
        case .trailing: return .trailing
        default: return .center
        }
    }
}

// MARK: - Beats Timeline View
struct BeatsTimelineView: View {
    let rhythm: String
    var tint: Color = Color.themeAccent

    /// "Slow, Quick, Quick" → S Q Q, so word rhythms fit the small tiles like counted ones ("1, 2, 3").
    var beats: [String] {
        rhythm.components(separatedBy: CharacterSet(charactersIn: ", ")).filter { !$0.isEmpty }.map { beat in
            switch beat.lowercased() {
            case "slow": return "S"
            case "quick": return "Q"
            case "and": return "&"
            default: return beat
            }
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(beats.prefix(8).enumerated()), id: \.offset) { _, beat in
                Text(beat)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 3)
                    .frame(minWidth: 15, minHeight: 15)
                    .background(tint.opacity(0.85), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
        }
    }
}

// MARK: - Partner Cursor View (Obsidian & Gold Presence)
struct PartnerCursorView: View {
    let name: String
    let isDragging: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ZStack {
                Circle()
                    .fill(Color.gold500.opacity(0.35))
                    .frame(width: 18, height: 18)
                    .blur(radius: 4)
                
                Image(systemName: isDragging ? "hand.draw.fill" : "arrow.up.left.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isDragging ? Color.gold400 : Color.gold500)
                    .shadow(color: Color.gold500.opacity(0.6), radius: 6)
            }
            
            HStack(spacing: 4) {
                Circle()
                    .fill(isDragging ? Color.gold400 : Color.syncEmerald)
                    .frame(width: 5, height: 5)
                Text(name.isEmpty ? "Partner" : name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.obsidian800)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.gold500.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 6, y: 2)
        }
    }
}

// MARK: - Canvas Connection Model
struct CanvasConnection: Identifiable {
    let from: CanvasNode
    let to: CanvasNode
    var id: String { "\(from.id.uuidString)-\(to.id.uuidString)" }
}
