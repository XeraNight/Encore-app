import Testing
import Foundation
import CoreGraphics
@testable import Encore

/// Figure names on the floor: a real 17-figure Slowfox fits with every name on a large iPhone, a name never covers
/// a circle or another name, and a crowded floor shows more names when zoomed in.
@MainActor
struct CanvasLabelLayoutTests {
    /// Jakub's routine "Prvý" as built on 29 Oct 2026 (floor points, routine order).
    private let slowfox: [(String, CGFloat, CGFloat)] = [
        ("Feather Step", 1820, 1900), ("Bounce followway", 1660, 1640), ("Pérové zakončenie", 1660, 1440),
        ("Trojkrok", 1680, 1280), ("Zatočený pérový krok", 1840, 1140), ("Zášvih", 1800, 960),
        ("Pletenec", 1500, 1020), ("Zášvih", 1200, 960), ("Chase", 1300, 1160),
        ("Bounce followway", 1340, 1360), ("Pérové zakončenie", 1340, 1580), ("Trojkrok", 1320, 1740),
        ("Zatočený pérový krok", 1160, 1880), ("Zášvih", 1180, 2040), ("Pletenec", 1480, 1980),
        ("Zášvih", 1760, 2040), ("Chase", 1660, 1800),
    ]

    private func pins(_ figures: [(String, CGFloat, CGFloat)]) -> [CanvasLabelLayout.Pin] {
        figures.map { CanvasLabelLayout.Pin(id: UUID(), center: CGPoint(x: $0.1, y: $0.2), text: $0.0) }
    }

    @Test func everyNameOfTheSlowfoxFitsTheWholeFloorOnAProMax() {
        let pins = pins(slowfox)
        // The whole floor on an iPhone 17 Pro Max (RoutineCanvasView.fitScale: 416 / 840).
        let placed = CanvasLabelLayout.place(pins, scale: 0.495, figureScale: 1)
        #expect(placed.count == pins.count)
        #expect(overlaps(pins, placed, scale: 0.495) == false)
    }

    @Test func aCrowdedFloorHidesNamesAndAZoomBringsThemBack() {
        // Twelve long names 60 floor points apart, a grid of four by three.
        let crowd = pins((0..<12).map { index -> (String, CGFloat, CGFloat) in
            let x: CGFloat = 1400 + CGFloat(index % 4) * 60
            let y: CGFloat = 1400 + CGFloat(index / 4) * 60
            return ("Zatočený pérový krok", x, y)
        })
        let whole = CanvasLabelLayout.place(crowd, scale: 0.5, figureScale: 1)
        let zoomed = CanvasLabelLayout.place(crowd, scale: 2, figureScale: 1)
        #expect(whole.count < crowd.count)
        #expect(zoomed.count > whole.count)
        #expect(overlaps(crowd, whole, scale: 0.5) == false)
        #expect(overlaps(crowd, zoomed, scale: 2) == false)
    }

    @Test func barsFollowTheName() {
        #expect(CanvasLabelLayout.text(name: "Trojkrok", bars: 2) == "Trojkrok · 2 t.")
        #expect(CanvasLabelLayout.text(name: "Trojkrok", bars: nil) == "Trojkrok")
    }

    /// Whether any placed name covers a circle or another placed name (screen points).
    private func overlaps(_ pins: [CanvasLabelLayout.Pin], _ placed: [UUID: CGPoint], scale: CGFloat) -> Bool {
        let radius = CanvasLabelLayout.circleSize / 2
        let circles = pins.map { CGRect(x: $0.center.x * scale - radius, y: $0.center.y * scale - radius, width: radius * 2, height: radius * 2) }
        let labels = pins.compactMap { pin -> CGRect? in
            guard let offset = placed[pin.id] else { return nil }
            let size = CanvasLabelLayout.size(of: pin.text)
            return CGRect(
                x: pin.center.x * scale + offset.x - size.width / 2,
                y: pin.center.y * scale + offset.y - size.height / 2,
                width: size.width,
                height: size.height
            )
        }
        for (index, label) in labels.enumerated() {
            if circles.contains(where: { $0.intersects(label) }) { return true }
            if labels.enumerated().contains(where: { $0.offset != index && $0.element.intersects(label) }) { return true }
        }
        return false
    }
}
