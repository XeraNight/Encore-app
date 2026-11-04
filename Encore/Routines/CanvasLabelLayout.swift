import UIKit

// MARK: - Figure names on the floor
/// Where each figure's name goes beside its circle, in screen points, so a pinch changes the answer: on the whole
/// floor a crowded name hides, zoomed in it comes back, like a place name on a map. A name never covers a circle,
/// another name, a transition button or a wall, and keeps off the lines when any side allows it.
enum CanvasLabelLayout {
    /// A figure's circle on screen at the standard figure size; the figure size menu scales it, never the name.
    static let circleSize: CGFloat = 32
    static let maxLabelWidth: CGFloat = 84
    static let maxLines = 2
    private static let gap: CGFloat = 4
    /// The visible part of a transition button, in floor points (the button zooms with the floor).
    private static let transitionButtonSize: CGFloat = 22

    /// The view draws the name with this font, so the measured size is the drawn size.
    static let font: UIFont = {
        let base = UIFont.systemFont(ofSize: 11, weight: .bold)
        return base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 11) } ?? base
    }()

    struct Pin {
        let id: UUID
        /// Floor points.
        let center: CGPoint
        let text: String
    }

    /// "Trojkrok · 2 t.": the name and, when set, the bars.
    static func text(name: String, bars: Int?) -> String {
        bars.map { "\(name) · \($0) t." } ?? name
    }

    /// The centre of each name relative to its circle's centre, in screen points. Pins come in routine order, so
    /// the earlier figure keeps its place; a pin missing from the result has no room at this zoom.
    static func place(_ pins: [Pin], scale: CGFloat, figureScale: CGFloat) -> [UUID: CGPoint] {
        let radius = circleSize * figureScale / 2
        let centers = pins.map { CGPoint(x: $0.center.x * scale, y: $0.center.y * scale) }
        let floor = CGRect(
            x: (BallroomFloorConfig.centerPoint.x - BallroomFloorConfig.floorWidth / 2) * scale,
            y: (BallroomFloorConfig.centerPoint.y - BallroomFloorConfig.floorHeight / 2) * scale,
            width: BallroomFloorConfig.floorWidth * scale,
            height: BallroomFloorConfig.floorHeight * scale
        )
        let buttonSide = transitionButtonSize * scale
        var blocked = centers.map { CGRect(x: $0.x - radius, y: $0.y - radius, width: radius * 2, height: radius * 2) }
        var lines: [(CGPoint, CGPoint)] = []
        for (from, to) in zip(centers, centers.dropFirst()) {
            let middle = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
            blocked.append(CGRect(x: middle.x - buttonSide / 2, y: middle.y - buttonSide / 2, width: buttonSide, height: buttonSide))
            let samples = ConnectionLineShape.samples(from: from, to: to)
            lines += zip(samples, samples.dropFirst()).map { ($0, $1) }
        }

        var placed: [UUID: CGPoint] = [:]
        for (pin, center) in zip(pins, centers) {
            let size = size(of: pin.text)
            let sides = [
                CGPoint(x: 0, y: radius + gap + size.height / 2),
                CGPoint(x: radius + gap + size.width / 2, y: 0),
                CGPoint(x: -(radius + gap + size.width / 2), y: 0),
                CGPoint(x: 0, y: -(radius + gap + size.height / 2)),
            ]
            let free = sides.map { offset in
                (offset, CGRect(
                    x: center.x + offset.x - size.width / 2,
                    y: center.y + offset.y - size.height / 2,
                    width: size.width,
                    height: size.height
                ))
            }
            .filter { _, rect in floor.contains(rect) && !blocked.contains { $0.intersects(rect) } }
            let clear = free.first { _, rect in !lines.contains { crosses(rect, $0.0, $0.1) } }
            guard let (offset, rect) = clear ?? free.first else { continue }
            placed[pin.id] = offset
            blocked.append(rect.insetBy(dx: -2, dy: -2))
        }
        return placed
    }

    /// The name's size on screen, at most `maxLabelWidth` wide and `maxLines` high (longer names end in "…").
    static func size(of text: String) -> CGSize {
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: maxLabelWidth, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: nil
        )
        return CGSize(width: ceil(bounds.width), height: ceil(min(bounds.height, font.lineHeight * CGFloat(maxLines))))
    }

    /// Whether the segment from `a` to `b` passes through the rectangle (Liang–Barsky clipping).
    private static func crosses(_ rect: CGRect, _ a: CGPoint, _ b: CGPoint) -> Bool {
        let dx = b.x - a.x, dy = b.y - a.y
        var enter: CGFloat = 0, exit: CGFloat = 1
        for (p, q) in [(-dx, a.x - rect.minX), (dx, rect.maxX - a.x), (-dy, a.y - rect.minY), (dy, rect.maxY - a.y)] {
            if p == 0 {
                if q < 0 { return false }
                continue
            }
            let t = q / p
            if p < 0 {
                if t > exit { return false }
                enter = max(enter, t)
            } else {
                if t < enter { return false }
                exit = min(exit, t)
            }
        }
        return true
    }
}
