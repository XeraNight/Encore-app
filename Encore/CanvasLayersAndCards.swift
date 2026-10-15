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
        let dx = to.x - from.x
        path.addCurve(
            to: to,
            control1: CGPoint(x: from.x + dx * 0.5, y: from.y),
            control2: CGPoint(x: from.x + dx * 0.5, y: to.y)
        )
        return path
    }
}

// MARK: - Canvas Node Card View
struct CanvasNodeCardView: View {
    @Bindable var node: CanvasNode
    /// Position in the routine as shown (1-based); a figure waiting to be deleted is left out.
    var number: Int? = nil
    let scale: CGFloat
    var cardScale: CGFloat = 1.0
    var isTranslucent: Bool = false
    var lockedByUserName: String? = nil
    var onTap: () -> Void
    var onDelete: () -> Void
    var onDrag: ((Double, Double) -> Void)? = nil
    var onDragStart: (() -> Void)? = nil
    var onDragEnd: ((Double, Double) -> Void)? = nil
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var showDeleteConfirm = false
    
    private var isLockedByPartner: Bool {
        lockedByUserName != nil
    }
    
    /// Zoomed far out the small details cannot be read anyway, so only the number and the name stay, bigger.
    private var isFarOut: Bool { scale < 0.5 }

    private var inkColor: Color { isTranslucent ? .white : Color.themeDark }
    private var accentColor: Color { isTranslucent ? Color.gold400 : Color.themeAccent }

    var body: some View {
        VStack(alignment: .leading, spacing: isFarOut ? 6 : 8) {
            HStack(spacing: 6) {
                Text("\(number ?? node.orderIndex + 1)")
                    .font(.system(size: isFarOut ? 20 : 13, weight: .black, design: .rounded))
                    .foregroundColor(Color.obsidian900)
                    .frame(width: isFarOut ? 34 : 24, height: isFarOut ? 34 : 24)
                    .background(
                        LinearGradient(colors: [Color.gold400, Color.gold500], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                Spacer(minLength: 0)

                if let lockedBy = lockedByUserName {
                    HStack(spacing: 3) {
                        Image(systemName: "lock.fill").font(.system(size: 8, weight: .bold))
                        Text(lockedBy).font(.system(size: 9, weight: .bold)).lineLimit(1)
                    }
                    .foregroundColor(.obsidian900)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.gold400, in: Capsule())
                } else if !isFarOut {
                    statusIcons
                }
            }

            Text(node.figureName)
                .font(.system(size: isFarOut ? 19 : 15, weight: .bold, design: .rounded))
                .foregroundColor(inkColor)
                .lineLimit(isFarOut ? 3 : 2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            if !isFarOut, !node.rhythm.isEmpty {
                BeatsTimelineView(rhythm: node.rhythm, tint: accentColor)
            }
        }
        .padding(12)
        .frame(width: 140, height: 132)
        .background(cardBackground)
        .scaleEffect(cardScale, anchor: .center)
        .frame(width: 140 * cardScale, height: 132 * cardScale)
        .overlay(
            Group {
                if isLockedByPartner {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gold400, lineWidth: 2)
                        .shadow(color: Color.gold500.opacity(0.5), radius: 8)
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button(action: onTap) { Label("Otvoriť figúru", systemImage: "arrow.up.right.square") }
            if !isLockedByPartner {
                Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Vymazať figúru", systemImage: "trash") }
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
                    
                    let bounds = BallroomFloorConfig.safeCardBounds(
                        cardWidth: 140 * cardScale,
                        cardHeight: 132 * cardScale,
                        wallMargin: 16
                    )
                    
                    let canvasDeltaX = value.translation.width / scale
                    let canvasDeltaY = value.translation.height / scale
                    
                    let rawLiveX = node.x + canvasDeltaX
                    let rawLiveY = node.y + canvasDeltaY
                    
                    let clampedLiveX = min(max(rawLiveX, bounds.minX), bounds.maxX)
                    let clampedLiveY = min(max(rawLiveY, bounds.minY), bounds.maxY)
                    
                    dragOffset = CGSize(width: clampedLiveX - node.x, height: clampedLiveY - node.y)
                    onDrag?(clampedLiveX, clampedLiveY)
                }
                .onEnded { value in
                    guard !isLockedByPartner else { return }
                    
                    let bounds = BallroomFloorConfig.safeCardBounds(
                        cardWidth: 140 * cardScale,
                        cardHeight: 132 * cardScale,
                        wallMargin: 16
                    )
                    
                    let canvasDeltaX = value.translation.width / scale
                    let canvasDeltaY = value.translation.height / scale
                    
                    let rawX = node.x + canvasDeltaX
                    let rawY = node.y + canvasDeltaY
                    
                    let clampedX = min(max(rawX, bounds.minX), bounds.maxX)
                    let clampedY = min(max(rawY, bounds.minY), bounds.maxY)
                    
                    // Magnetic Snap to 20pt ballroom grid strictly within boundaries
                    let snappedX = min(max((clampedX / 20.0).rounded() * 20.0, bounds.minX), bounds.maxX)
                    let snappedY = min(max((clampedY / 20.0).rounded() * 20.0, bounds.minY), bounds.maxY)
                    
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
        .confirmationDialog("Vymazať túto figúru zo zostavy?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Vymazať", role: .destructive) { onDelete() }
            Button("Zrušiť", role: .cancel) {}
        }
    }
}

extension CanvasNodeCardView {
    /// Small markers: video, own notes, a remark from the coach.
    @ViewBuilder
    fileprivate var statusIcons: some View {
        HStack(spacing: 5) {
            if node.displayVideoPath != nil {
                Image(systemName: "video.fill")
            }
            if !node.notes.isEmpty {
                Image(systemName: "doc.text.fill")
            }
            if let remark = node.coachNotes, !remark.isEmpty {
                Image(systemName: "person.badge.shield.checkmark.fill")
            }
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(accentColor.opacity(0.9))
    }

    fileprivate var cardBackground: some View {
        Group {
            if isTranslucent {
                // Frosted glass: the parquet grain shows through.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.obsidian900.opacity(0.42)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                LinearGradient(colors: [Color.gold300.opacity(0.65), Color.gold500.opacity(0.25)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 10, y: 5)
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.themeCard)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.themeDark.opacity(0.12), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.22), radius: 8, y: 4)
            }
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
