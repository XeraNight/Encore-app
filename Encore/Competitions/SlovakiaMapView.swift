import SwiftUI

// MARK: - Cities
/// Towns where competitions happen, with their place on the map. KSIS gives a free-text address, so the town is
/// looked up in it; a place not in this table simply has no pin and stays in the list.
nonisolated struct SlovakCity: Equatable, Identifiable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double
    /// Other forms found in KSIS addresses ("v Nitre").
    var forms: [String] = []
    /// Marked on the map even without a competition, so the map reads as Slovakia.
    var isLandmark = false

    var id: String { name }

    static let all: [SlovakCity] = [
        SlovakCity(name: "Bratislava", latitude: 48.148, longitude: 17.107, forms: ["Bratislave"], isLandmark: true),
        SlovakCity(name: "Košice", latitude: 48.716, longitude: 21.261, forms: ["Košiciach"], isLandmark: true),
        SlovakCity(name: "Prešov", latitude: 48.998, longitude: 21.240, forms: ["Prešove"], isLandmark: true),
        SlovakCity(name: "Žilina", latitude: 49.223, longitude: 18.739, forms: ["Žiline"], isLandmark: true),
        SlovakCity(name: "Banská Bystrica", latitude: 48.736, longitude: 19.146, forms: ["Banskej Bystrici"], isLandmark: true),
        SlovakCity(name: "Nitra", latitude: 48.307, longitude: 18.087, forms: ["Nitre"], isLandmark: true),
        SlovakCity(name: "Trnava", latitude: 48.377, longitude: 17.588, forms: ["Trnave"], isLandmark: true),
        SlovakCity(name: "Trenčín", latitude: 48.894, longitude: 18.044, forms: ["Trenčíne"], isLandmark: true),
        SlovakCity(name: "Poprad", latitude: 49.056, longitude: 20.297, forms: ["Poprade"], isLandmark: true),
        SlovakCity(name: "Martin", latitude: 49.066, longitude: 18.923, forms: ["Martine"]),
        SlovakCity(name: "Prievidza", latitude: 48.775, longitude: 18.624, forms: ["Prievidzi"]),
        SlovakCity(name: "Zvolen", latitude: 48.575, longitude: 19.125, forms: ["Zvolene"]),
        SlovakCity(name: "Považská Bystrica", latitude: 49.115, longitude: 18.449, forms: ["Považskej Bystrici"]),
        SlovakCity(name: "Nové Zámky", latitude: 47.986, longitude: 18.162, forms: ["Nových Zámkoch"]),
        SlovakCity(name: "Michalovce", latitude: 48.755, longitude: 21.919, forms: ["Michalovciach"]),
        SlovakCity(name: "Spišská Nová Ves", latitude: 48.946, longitude: 20.561, forms: ["Spišskej Novej Vsi"]),
        SlovakCity(name: "Komárno", latitude: 47.763, longitude: 18.129, forms: ["Komárne"]),
        SlovakCity(name: "Levice", latitude: 48.216, longitude: 18.607, forms: ["Leviciach"]),
        SlovakCity(name: "Humenné", latitude: 48.937, longitude: 21.906, forms: ["Humennom"]),
        SlovakCity(name: "Bardejov", latitude: 49.292, longitude: 21.275, forms: ["Bardejove"]),
        SlovakCity(name: "Liptovský Mikuláš", latitude: 49.083, longitude: 19.612, forms: ["Liptovskom Mikuláši"]),
        SlovakCity(name: "Ružomberok", latitude: 49.075, longitude: 19.303, forms: ["Ružomberku"]),
        SlovakCity(name: "Piešťany", latitude: 48.591, longitude: 17.827, forms: ["Piešťanoch"]),
        SlovakCity(name: "Lučenec", latitude: 48.329, longitude: 19.667, forms: ["Lučenci"]),
        SlovakCity(name: "Topoľčany", latitude: 48.561, longitude: 18.171, forms: ["Topoľčanoch"]),
        SlovakCity(name: "Senec", latitude: 48.220, longitude: 17.400, forms: ["Senci"]),
        SlovakCity(name: "Šamorín", latitude: 48.031, longitude: 17.312, forms: ["Šamoríne"]),
        SlovakCity(name: "Pezinok", latitude: 48.289, longitude: 17.267, forms: ["Pezinku"]),
        SlovakCity(name: "Nové Mesto nad Váhom", latitude: 48.755, longitude: 17.831),
        SlovakCity(name: "Žiar nad Hronom", latitude: 48.592, longitude: 18.853),
        SlovakCity(name: "Dunajská Streda", latitude: 47.994, longitude: 17.619, forms: ["Dunajskej Strede"]),
        SlovakCity(name: "Rimavská Sobota", latitude: 48.383, longitude: 20.022, forms: ["Rimavskej Sobote"]),
        SlovakCity(name: "Turany", latitude: 49.136, longitude: 19.048, forms: ["Turanoch"]),
        SlovakCity(name: "Malacky", latitude: 48.436, longitude: 17.021, forms: ["Malackách"]),
        SlovakCity(name: "Partizánske", latitude: 48.628, longitude: 18.384, forms: ["Partizánskom"]),
        SlovakCity(name: "Hlohovec", latitude: 48.431, longitude: 17.803, forms: ["Hlohovci"]),
        SlovakCity(name: "Dubnica nad Váhom", latitude: 48.960, longitude: 18.170),
        SlovakCity(name: "Púchov", latitude: 49.120, longitude: 18.326, forms: ["Púchove"]),
        SlovakCity(name: "Kežmarok", latitude: 49.136, longitude: 20.431, forms: ["Kežmarku"]),
        SlovakCity(name: "Stará Ľubovňa", latitude: 49.300, longitude: 20.686, forms: ["Starej Ľubovni"]),
        SlovakCity(name: "Vranov nad Topľou", latitude: 48.889, longitude: 21.684),
        SlovakCity(name: "Snina", latitude: 48.987, longitude: 22.151, forms: ["Snine"]),
        SlovakCity(name: "Galanta", latitude: 48.190, longitude: 17.727, forms: ["Galante"]),
        SlovakCity(name: "Senica", latitude: 48.679, longitude: 17.367, forms: ["Senici"]),
        SlovakCity(name: "Skalica", latitude: 48.845, longitude: 17.227, forms: ["Skalici"]),
        SlovakCity(name: "Šaľa", latitude: 48.151, longitude: 17.881, forms: ["Šali"]),
        SlovakCity(name: "Rožňava", latitude: 48.661, longitude: 20.532, forms: ["Rožňave"]),
        SlovakCity(name: "Brezno", latitude: 48.806, longitude: 19.638, forms: ["Brezne"]),
        SlovakCity(name: "Dolný Kubín", latitude: 49.209, longitude: 19.295, forms: ["Dolnom Kubíne"]),
        SlovakCity(name: "Čadca", latitude: 49.439, longitude: 18.788, forms: ["Čadci"]),
    ]

    /// The town in a KSIS address. A town closes the address, so the last one found wins over a street named
    /// after another; nil when there is none, never a guess.
    static func find(in venue: String) -> SlovakCity? {
        let text = folded(venue)
        var best: (city: SlovakCity, end: String.Index)?
        for city in all {
            for form in [city.name] + city.forms {
                for range in text.ranges(of: folded(form)) where isWhole(range, in: text) {
                    if best == nil || range.upperBound > best!.end { best = (city, range.upperBound) }
                }
            }
        }
        return best?.city
    }

    private static func isWhole(_ range: Range<String.Index>, in text: String) -> Bool {
        let before = range.lowerBound == text.startIndex ? nil : text[text.index(before: range.lowerBound)]
        let after = range.upperBound == text.endIndex ? nil : text[range.upperBound]
        return !(before?.isLetter ?? false) && !(after?.isLetter ?? false)
    }

    private static func folded(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "sk"))
    }
}

// MARK: - Outline
/// Slovakia drawn from its border, simplified: a brand map, not a road map. Longitude and latitude map to the frame
/// directly; the frame's aspect ratio corrects for the latitude.
struct SlovakiaOutline: Shape {
    static let west = 16.75, east = 22.7, north = 49.68, south = 47.65
    /// The width of a degree of longitude at this latitude, against a degree of latitude.
    static let aspectRatio = (east - west) * 0.66 / (north - south)

    private static let border: [(lon: Double, lat: Double)] = [
        (16.97, 48.15), (16.85, 48.35), (16.95, 48.55), (17.05, 48.75), (17.2, 48.86), (17.4, 48.82), (17.55, 48.8),
        (17.72, 48.87), (17.9, 48.98), (18.08, 49.05), (18.12, 49.2), (18.3, 49.3), (18.45, 49.42), (18.62, 49.5),
        (18.85, 49.52), (19.0, 49.42), (19.22, 49.4), (19.42, 49.58), (19.55, 49.58), (19.78, 49.42), (19.78, 49.2),
        (19.95, 49.24), (20.1, 49.2), (20.18, 49.32), (20.35, 49.4), (20.6, 49.38), (20.75, 49.42), (20.93, 49.3),
        (21.08, 49.43), (21.3, 49.45), (21.6, 49.44), (21.85, 49.38), (22.05, 49.22), (22.3, 49.15), (22.56, 49.09),
        (22.55, 48.98), (22.4, 48.87), (22.35, 48.68), (22.15, 48.41), (21.95, 48.37), (21.72, 48.35), (21.58, 48.5),
        (21.4, 48.57), (21.1, 48.5), (20.85, 48.58), (20.65, 48.55), (20.45, 48.47), (20.33, 48.27), (20.1, 48.25),
        (19.92, 48.13), (19.68, 48.2), (19.5, 48.2), (19.25, 48.07), (19.0, 48.07), (18.85, 47.95), (18.8, 47.82),
        (18.45, 47.78), (18.1, 47.75), (17.8, 47.75), (17.5, 47.87), (17.25, 48.02), (17.08, 48.04),
    ]

    static func point(longitude: Double, latitude: Double, in size: CGSize) -> CGPoint {
        CGPoint(x: (longitude - west) / (east - west) * size.width, y: (north - latitude) / (north - south) * size.height)
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points = Self.border.map { Self.point(longitude: $0.lon, latitude: $0.lat, in: rect.size) }
        guard let first = points.first else { return path }
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }
}

// MARK: - Map
/// Competitions on Slovakia: a pin with the count in each town. The border draws itself and the pins come in one by
/// one; a tap moves in on the town, another tap steps back. The town's name is shown where its competitions are
/// listed, never over the map, where it would cover the next pin. Meant to fill its card edge to edge.
struct SlovakiaMapView: View {
    /// Competitions per town, after the filters.
    let counts: [String: Int]
    @Binding var selected: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How much of the border is drawn.
    @State private var drawn: CGFloat = 0
    @State private var pinsAreIn = false

    /// Pins stay this far apart, centre to centre, so each one can be tapped.
    private static let pinSpacing: CGFloat = 28
    /// How far the map moves in on a picked town.
    private static let zoom: CGFloat = 1.3

    private var cities: [SlovakCity] { SlovakCity.all.filter { counts[$0.name] != nil } }
    private var spring: Animation? { reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.8) }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let towns = cities.map { position(of: $0, in: size) }
            let pins = Self.spreadOut(towns, spacing: Self.pinSpacing, in: size)
            let picked = cities.firstIndex { $0.name == selected }
            ZStack(alignment: .topLeading) {
                SlovakiaOutline().fill(Color.white.opacity(0.08 * drawn))
                SlovakiaOutline()
                    .trim(from: 0, to: drawn)
                    .stroke(Color.gold400.opacity(0.55), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
                ties(from: towns, to: pins)
                ForEach(landmarks(clearOf: pins, in: size)) { city in
                    landmark(city)
                        .position(position(of: city, in: size))
                        .transition(.opacity)
                }
                ForEach(Array(cities.enumerated()), id: \.element.id) { index, city in
                    pin(city, order: index)
                        .position(pins[index])
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .scaleEffect(picked == nil ? 1 : Self.zoom, anchor: picked.map { anchor(pins[$0], in: size) } ?? .center)
        }
        .aspectRatio(SlovakiaOutline.aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(spring, value: counts)
        .animation(spring, value: selected)
        .onAppear(perform: comeIn)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mapa súťaží na Slovensku")
    }

    private func position(of city: SlovakCity, in size: CGSize) -> CGPoint {
        SlovakiaOutline.point(longitude: city.longitude, latitude: city.latitude, in: size)
    }

    private func comeIn() {
        guard !reduceMotion else {
            drawn = 1
            pinsAreIn = true
            return
        }
        withAnimation(.easeOut(duration: 0.8)) { drawn = 1 }
        pinsAreIn = true
    }

    private func anchor(_ point: CGPoint, in size: CGSize) -> UnitPoint {
        UnitPoint(x: point.x / max(size.width, 1), y: point.y / max(size.height, 1))
    }

    /// Towns around Bratislava lie closer than a finger: their pins move apart just enough, each staying tied to its town.
    static func spreadOut(_ points: [CGPoint], spacing: CGFloat, in size: CGSize) -> [CGPoint] {
        var spread = points
        for _ in 0..<80 {
            var moved = false
            for first in spread.indices {
                for second in spread.indices where second > first {
                    let dx = spread[second].x - spread[first].x
                    let dy = spread[second].y - spread[first].y
                    let distance = hypot(dx, dy)
                    guard distance < spacing else { continue }
                    let (unitX, unitY) = distance > 0.01 ? (dx / distance, dy / distance) : (1, 0)
                    let push = (spacing - distance) / 2 + 0.1
                    spread[first].x -= unitX * push
                    spread[first].y -= unitY * push
                    spread[second].x += unitX * push
                    spread[second].y += unitY * push
                    moved = true
                }
            }
            let margin = spacing / 2
            for index in spread.indices {
                spread[index].x = min(max(spread[index].x, margin), size.width - margin)
                spread[index].y = min(max(spread[index].y, margin), size.height - margin)
            }
            if !moved { break }
        }
        return spread
    }

    /// A thin line from a pin that moved back to its town.
    private func ties(from towns: [CGPoint], to pins: [CGPoint]) -> some View {
        Path { path in
            for (town, pin) in zip(towns, pins) where hypot(town.x - pin.x, town.y - pin.y) > 1 {
                path.move(to: town)
                path.addLine(to: pin)
            }
        }
        .stroke(Color.gold400.opacity(0.6), lineWidth: 1)
        .allowsHitTesting(false)
    }

    /// Main towns without a pin, so the map reads as Slovakia; a name under a pin would only be half seen.
    private func landmarks(clearOf pins: [CGPoint], in size: CGSize) -> [SlovakCity] {
        SlovakCity.all.filter { city in
            guard city.isLandmark, counts[city.name] == nil else { return false }
            let point = position(of: city, in: size)
            return !pins.contains { abs($0.x - point.x) < 46 && abs($0.y - point.y) < 30 }
        }
    }

    private func landmark(_ city: SlovakCity) -> some View {
        VStack(spacing: 2) {
            Circle().fill(Color.white.opacity(0.35)).frame(width: 4, height: 4)
            Text(city.name)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.45))
                .fixedSize()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func pin(_ city: SlovakCity, order: Int) -> some View {
        let isSelected = selected == city.name
        return Button {
            selected = isSelected ? nil : city.name
        } label: {
            Text("\(counts[city.name] ?? 0)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(isSelected ? Color.obsidian900 : Color.gold300)
                .contentTransition(.numericText())
                .frame(width: 24, height: 24)
                .background(isSelected ? Color.gold400 : Color.encoreCrimson, in: Circle())
                .overlay(Circle().stroke(Color.gold400, lineWidth: 1.5))
                .background {
                    if isSelected && !reduceMotion { pulse }
                }
                .scaleEffect(isSelected ? 1.1 : 1)
                .frame(width: Self.pinSpacing, height: Self.pinSpacing)
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .scaleEffect(pinsAreIn ? 1 : 0.2)
        .opacity(pinsAreIn ? 1 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.65).delay(0.25 + Double(order) * 0.03), value: pinsAreIn)
        .zIndex(isSelected ? 1 : 0)
        .accessibilityLabel("\(city.name), súťaží: \(counts[city.name] ?? 0)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// A ring leaving the picked town, so the eye finds it on the map.
    private var pulse: some View {
        Circle()
            .stroke(Color.gold400, lineWidth: 1.5)
            .phaseAnimator([false, true]) { ring, isOut in
                ring.scaleEffect(isOut ? 1.9 : 1).opacity(isOut ? 0 : 0.8)
            } animation: { isOut in
                isOut ? .easeOut(duration: 1.3) : nil
            }
    }
}
