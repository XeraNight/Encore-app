import SwiftUI

// MARK: - Helper lines for video analysis
/// Two lines that are always perfectly straight, so they measure what a finger drawing never could:
/// a plumb line (vertical) moved to the standing leg, and a level line moved to the shoulders or hips and
/// turned with two fingers to read the tilt. Positions are fractions of the picture, so the lines stay put
/// when the layout changes size.
struct AnalysisGuides: Equatable {
    var showsPlumb = true
    var showsLevel = true
    /// Plumb line position, 0…1 of the width.
    var plumbX: Double = 0.5
    /// Level line centre, 0…1 of the height.
    var levelY: Double = 0.3
    /// Tilt of the level line in degrees. Positive: the right side of the picture is lower.
    var levelAngle: Double = 0

    static let maxAngle: Double = 45

    /// The tilt in whole degrees, as the label and the correction note show it.
    var roundedAngle: Int { Int(abs(levelAngle).rounded()) }

    mutating func movePlumb(toFraction x: Double) {
        plumbX = min(max(x, 0), 1)
    }

    mutating func moveLevel(toFraction y: Double) {
        levelY = min(max(y, 0), 1)
    }

    mutating func setAngle(_ degrees: Double) {
        levelAngle = min(max(degrees, -Self.maxAngle), Self.maxAngle)
    }

    /// Start and end of the level line across a picture of the given size.
    func levelEndpoints(in size: CGSize) -> (CGPoint, CGPoint) {
        let centre = CGPoint(x: size.width / 2, y: levelY * size.height)
        let radians = levelAngle * .pi / 180
        let half = size.width   // long enough to cross the whole picture at any allowed tilt
        let dx = cos(radians) * half
        let dy = sin(radians) * half
        return (CGPoint(x: centre.x - dx, y: centre.y - dy), CGPoint(x: centre.x + dx, y: centre.y + dy))
    }
}

// MARK: - Drawing (screen and saved snapshot)
/// The lines and the tilt label, without touch handling. The snapshot renders exactly this view.
struct AnalysisGuidesDrawing: View {
    let guides: AnalysisGuides

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                if guides.showsPlumb {
                    Path { path in
                        path.move(to: CGPoint(x: guides.plumbX * size.width, y: 0))
                        path.addLine(to: CGPoint(x: guides.plumbX * size.width, y: size.height))
                    }
                    .stroke(Color.gold400, style: StrokeStyle(lineWidth: 2))
                    .shadow(color: .black.opacity(0.6), radius: 1.5)
                }

                if guides.showsLevel {
                    let (start, end) = guides.levelEndpoints(in: size)
                    Path { path in
                        path.move(to: start)
                        path.addLine(to: end)
                    }
                    .stroke(Color.latinRed, style: StrokeStyle(lineWidth: 2))
                    .shadow(color: .black.opacity(0.6), radius: 1.5)

                    Text("\(guides.roundedAngle)°")
                        .font(.system(.footnote, design: .rounded).weight(.heavy))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.latinRed, in: Capsule())
                        .position(x: size.width - 34, y: guides.levelY * size.height
                                  + tan(guides.levelAngle * .pi / 180) * (size.width / 2 - 34) - 18)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Interactive overlay
/// Drag the plumb line sideways, drag the level line up or down, turn it with two fingers.
/// Double-tap the picture to level the line again.
struct AnalysisGuidesOverlay: View {
    @Binding var guides: AnalysisGuides

    @State private var angleAtGestureStart: Double?
    @State private var touches = 0

    private static let space = "analysisGuides"

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                AnalysisGuidesDrawing(guides: guides)

                if guides.showsLevel {
                    // A 44 pt band along the level line catches the finger.
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: size.width * 1.5, height: 44)
                        .contentShape(Rectangle())
                        .rotationEffect(.degrees(guides.levelAngle))
                        .position(x: size.width / 2, y: guides.levelY * size.height)
                        .gesture(
                            DragGesture(coordinateSpace: .named(Self.space))
                                .onChanged { value in
                                    guides.moveLevel(toFraction: value.location.y / max(size.height, 1))
                                }
                                .onEnded { _ in touches += 1 }
                        )
                        .accessibilityElement()
                        .accessibilityLabel("Vodorovná čiara, sklon \(guides.roundedAngle) stupňov")
                        .accessibilityAdjustableAction { direction in
                            guides.setAngle(guides.levelAngle + (direction == .increment ? 1 : -1))
                        }
                }

                if guides.showsPlumb {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 44, height: size.height)
                        .contentShape(Rectangle())
                        .position(x: guides.plumbX * size.width, y: size.height / 2)
                        .gesture(
                            DragGesture(coordinateSpace: .named(Self.space))
                                .onChanged { value in
                                    guides.movePlumb(toFraction: value.location.x / max(size.width, 1))
                                }
                                .onEnded { _ in touches += 1 }
                        )
                        .accessibilityElement()
                        .accessibilityLabel("Olovnica")
                        .accessibilityAdjustableAction { direction in
                            guides.movePlumb(toFraction: guides.plumbX + (direction == .increment ? 0.01 : -0.01))
                        }
                }
            }
            .frame(width: size.width, height: size.height)
            .coordinateSpace(.named(Self.space))
            .contentShape(Rectangle())
            .simultaneousGesture(
                RotateGesture()
                    .onChanged { value in
                        guard guides.showsLevel else { return }
                        let start = angleAtGestureStart ?? guides.levelAngle
                        angleAtGestureStart = start
                        guides.setAngle(start + value.rotation.degrees)
                    }
                    .onEnded { _ in
                        angleAtGestureStart = nil
                        touches += 1
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { guides.setAngle(0) }
                touches += 1
            }
        }
        .sensoryFeedback(.selection, trigger: touches)
        .sensoryFeedback(.selection, trigger: guides.roundedAngle)
    }
}
