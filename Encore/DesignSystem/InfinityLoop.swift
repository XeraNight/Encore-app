import SwiftUI

// MARK: - The curve
/// A figure of eight lying on its side: the path of the Encore loader, the line of dance in one stroke.
/// x = cos t, y = ½ sin 2t, walked at an even pace by length so the light does not rush through the middle.
enum InfinityCurve {
    /// Height over width.
    nonisolated static let heightRatio: CGFloat = 0.5

    /// How far along the curve's length each sample is, 0...1. Sample `i` is at t = 2π · i / (count - 1).
    private nonisolated static let lengths: [Double] = {
        let count = 360
        var cumulative = [0.0]
        var previous = raw(0)
        var total = 0.0
        for i in 1...count {
            let next = raw(2 * Double.pi * Double(i) / Double(count))
            total += hypot(next.x - previous.x, next.y - previous.y)
            cumulative.append(total)
            previous = next
        }
        return cumulative.map { $0 / total }
    }()

    private nonisolated static func raw(_ t: Double) -> (x: Double, y: Double) {
        (cos(t), 0.5 * sin(2 * t))
    }

    /// The point `progress` of the way along the curve's length (0...1, anything else wraps round).
    /// x is in -1...1 and y in -0.5...0.5.
    nonisolated static func point(at progress: Double) -> CGPoint {
        let wrapped = progress - progress.rounded(.down)
        var low = 0
        var high = lengths.count - 1
        while high - low > 1 {
            let middle = (low + high) / 2
            if lengths[middle] <= wrapped { low = middle } else { high = middle }
        }
        let span = lengths[high] - lengths[low]
        let fraction = span > 0 ? (wrapped - lengths[low]) / span : 0
        let t = 2 * Double.pi * (Double(low) + fraction) / Double(lengths.count - 1)
        let p = raw(t)
        return CGPoint(x: p.x, y: p.y)
    }
}

// MARK: - The loader
/// The one loader of the app: a gold light that runs round a figure of eight. With Reduce Motion the figure
/// only breathes. Use it where the app waits for something that takes a moment (KSIS, the network, saving).
struct InfinityLoopView: View {
    /// Width of the figure; the height follows.
    var width: CGFloat = 48
    var color: Color = .gold400
    /// Seconds for one lap of the light.
    var period: Double = 2.0
    /// A soft glow round the head of the light. Off for a dark loader on a light button, where it would only smudge.
    var glow = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathIn = false

    private var line: CGFloat { max(2.2, width * 0.075) }
    private var height: CGFloat { (width - 2 * line) * InfinityCurve.heightRatio + 2 * line }
    /// Room round the figure for the glow, so it fades out instead of being cut at the edge of the drawing.
    private var room: CGFloat { glow ? line * 4 : 0 }

    var body: some View {
        Group {
            if reduceMotion {
                Canvas { context, size in
                    Self.draw(&context, size: size, lap: nil, color: color, line: line, room: room, glow: glow)
                }
                .frame(width: width + 2 * room, height: height + 2 * room)
                .opacity(breathIn ? 1 : 0.45)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { breathIn = true }
                }
            } else {
                // 60 images a second are enough for a light this small, also on a 120 Hz screen; in Low Power Mode 30.
                TimelineView(.animation(minimumInterval: ProcessInfo.processInfo.isLowPowerModeEnabled ? 1.0 / 30 : 1.0 / 60)) { timeline in
                    let lap = (timeline.date.timeIntervalSinceReferenceDate / period).truncatingRemainder(dividingBy: 1)
                    Canvas { context, size in
                        Self.draw(&context, size: size, lap: lap, color: color, line: line, room: room, glow: glow)
                    }
                    .frame(width: width + 2 * room, height: height + 2 * room)
                }
            }
        }
        .frame(width: width, height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Načítavam")
    }

    /// `lap` is where the light is on its way round (0...1); nil draws the figure alone.
    nonisolated private static func draw(_ context: inout GraphicsContext, size: CGSize, lap: Double?, color: Color,
                                         line: CGFloat, room: CGFloat, glow: Bool) {
        let scale = (size.width - 2 * room - 2 * line) / 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        func place(_ progress: Double) -> CGPoint {
            let p = InfinityCurve.point(at: progress)
            return CGPoint(x: center.x + p.x * scale, y: center.y + p.y * scale)
        }

        // The faint figure the light runs on.
        var track = Path()
        track.move(to: place(0))
        for i in 1...96 { track.addLine(to: place(Double(i) / 96)) }
        context.stroke(track, with: .color(color.opacity(lap == nil ? 0.95 : 0.16)),
                       style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
        guard let lap else { return }

        // The tail: layers of the same path laid over each other, each shorter and thicker than the one before. Where
        // more layers meet the light is brighter, so it fades smoothly, with no beads and no gaps at the bends.
        let layers = 18
        let tail = 0.4
        for k in 0..<layers {
            let covers = Double(k + 1) / Double(layers)
            let points = max(3, Int(covers * 44))
            var path = Path()
            path.move(to: place(lap))
            for j in 1...points { path.addLine(to: place(lap - tail * covers * Double(j) / Double(points))) }
            context.stroke(path, with: .color(color.opacity(k >= layers - 3 ? 0.08 : 0.16)),
                           style: StrokeStyle(lineWidth: line * (1 - 0.55 * covers), lineCap: .round, lineJoin: .round))
        }

        // The head: a soft glow with a bright point in it.
        let head = place(lap)
        if glow {
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: line * 1.2))
                layer.fill(Path(ellipseIn: CGRect(x: head.x - line * 1.1, y: head.y - line * 1.1, width: line * 2.2, height: line * 2.2)),
                           with: .color(color.opacity(0.85)))
            }
        }
        context.fill(Path(ellipseIn: CGRect(x: head.x - line * 0.62, y: head.y - line * 0.62, width: line * 1.24, height: line * 1.24)),
                     with: .color(color))
        if glow {
            context.fill(Path(ellipseIn: CGRect(x: head.x - line * 0.3, y: head.y - line * 0.3, width: line * 0.6, height: line * 0.6)),
                         with: .color(.white.opacity(0.95)))
        }
    }
}
