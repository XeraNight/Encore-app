import SwiftUI

// MARK: - The curve
/// A figure of eight lying on its side, the path of the Encore loader and the line of dance in one stroke. Its shape
/// follows the loop picked on 21st.dev: two round lobes joined by gentle S-curves, with no sharp corner anywhere. It is
/// six cubic curves, walked at an even pace by length so the light does not rush through the middle.
enum InfinityCurve {
    /// Height over width.
    nonisolated static let heightRatio: CGFloat = 0.444

    /// The six curves (start, two controls, end), in unit coordinates: x in -1...1, y in -0.444...0.444, y down.
    /// It starts at the right end and runs down, so the first stretch is the lower half of the right lobe.
    private nonisolated static let curves: [[(x: Double, y: Double)]] = {
        let centre = 0.57   // where the S-curves meet a lobe, left or right of the middle
        let height = 0.444  // how far a lobe reaches up and down
        let reach = 0.29    // how far the lobe's controls stand out sideways
        let round = 0.15    // how far the controls at the lobe's end stand up and down
        let glide = 0.43    // how long the S-curve's controls are
        return [
            [(1, 0), (1, round), (centre + reach, height), (centre, height)],
            [(centre, height), (centre - glide, height), (-(centre - glide), -height), (-centre, -height)],
            [(-centre, -height), (-(centre + reach), -height), (-1, -round), (-1, 0)],
            [(-1, 0), (-1, round), (-(centre + reach), height), (-centre, height)],
            [(-centre, height), (-(centre - glide), height), (centre - glide, -height), (centre, -height)],
            [(centre, -height), (centre + reach, -height), (1, -round), (1, 0)]
        ]
    }()

    /// Points along the curve with the length walked so far, 0...1.
    private nonisolated static let samples: [(x: Double, y: Double, length: Double)] = {
        let steps = 48
        var points: [(x: Double, y: Double)] = []
        for curve in curves {
            for i in 0..<steps {
                let t = Double(i) / Double(steps)
                let u = 1 - t
                let x = u * u * u * curve[0].x + 3 * u * u * t * curve[1].x + 3 * u * t * t * curve[2].x + t * t * t * curve[3].x
                let y = u * u * u * curve[0].y + 3 * u * u * t * curve[1].y + 3 * u * t * t * curve[2].y + t * t * t * curve[3].y
                points.append((x, y))
            }
        }
        points.append((1, 0))
        var walked = [0.0]
        for i in 1..<points.count {
            walked.append(walked[i - 1] + hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y))
        }
        let total = walked[walked.count - 1]
        return points.enumerated().map { (x: $0.element.x, y: $0.element.y, length: walked[$0.offset] / total) }
    }()

    /// The point `progress` of the way along the curve's length (0...1, anything else wraps round).
    nonisolated static func point(at progress: Double) -> CGPoint {
        let wrapped = progress - progress.rounded(.down)
        var low = 0
        var high = samples.count - 1
        while high - low > 1 {
            let middle = (low + high) / 2
            if samples[middle].length <= wrapped { low = middle } else { high = middle }
        }
        let span = samples[high].length - samples[low].length
        let fraction = span > 0 ? (wrapped - samples[low].length) / span : 0
        return CGPoint(x: samples[low].x + (samples[high].x - samples[low].x) * fraction,
                       y: samples[low].y + (samples[high].y - samples[low].y) * fraction)
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

    private var line: CGFloat { max(2.5, width * 0.10) }
    private var height: CGFloat { (width - line) * InfinityCurve.heightRatio + line }
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
        // The curve's half width: the stroke's round ends add half a line on each side, and the whole is `width` wide.
        let scale = (size.width - 2 * room - line) / 2
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

        // The tail: the same stretch of the path stroked many times, each time one step shorter than before, always as thick
        // as the figure with round ends. Where more strokes meet the light is brighter, so it fades smoothly towards the end
        // with no beads, no gaps at the bends and no thin sharp tip. The steps are small enough that no stair shows.
        let steps = 48
        let tail = 0.4
        let spots = (0...steps).map { place(lap - tail * Double($0) / Double(steps)) }
        for length in 1...steps {
            var path = Path()
            path.addLines(Array(spots[0...length]))
            context.stroke(path, with: .color(color.opacity(0.06)),
                           style: StrokeStyle(lineWidth: line, lineCap: .round, lineJoin: .round))
        }

        // The head: a soft glow with a bright point in it.
        let head = place(lap)
        if glow {
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: line * 1.2))
                layer.fill(Path(ellipseIn: CGRect(x: head.x - line * 0.9, y: head.y - line * 0.9, width: line * 1.8, height: line * 1.8)),
                           with: .color(color.opacity(0.85)))
            }
        }
        context.fill(Path(ellipseIn: CGRect(x: head.x - line * 0.5, y: head.y - line * 0.5, width: line, height: line)),
                     with: .color(color))
        if glow {
            context.fill(Path(ellipseIn: CGRect(x: head.x - line * 0.22, y: head.y - line * 0.22, width: line * 0.44, height: line * 0.44)),
                         with: .color(.white.opacity(0.95)))
        }
    }
}
