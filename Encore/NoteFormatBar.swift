import SwiftUI

/// Formatting bar shown at the bottom while a note is being written: highlight / underline, font,
/// colour, alignment, size and a voice note where the cursor is. Every format button applies to the
/// selected words (or to what is typed next when nothing is selected).
struct NoteFormatBar: View {
    /// Applies one formatting change through the editor.
    let onFormat: ((inout AttributeContainer) -> Void) -> Void
    let isRecording: Bool
    let onVoice: () -> Void
    let onDone: () -> Void

    @State private var size: CGFloat = NoteStyle.defaultSize
    @State private var design: Font.Design = .default
    @State private var isBold = false
    @State private var alignment: TextAlignment = .leading

    private struct InkColor: Identifiable {
        let name: String
        /// nil = the default light ink.
        let color: Color?
        var id: String { name }
    }

    /// Bright enough to read on the dark notes card.
    private let inks: [InkColor] = [
        InkColor(name: "Biela", color: nil),
        InkColor(name: "Zlatá", color: Color.gold400),
        InkColor(name: "Červená", color: Color(red: 1.0, green: 0.45, blue: 0.50)),
        InkColor(name: "Modrá", color: Color(red: 0.50, green: 0.70, blue: 1.0)),
        InkColor(name: "Zelená", color: Color(red: 0.40, green: 0.88, blue: 0.60)),
        InkColor(name: "Oranžová", color: Color(red: 1.0, green: 0.68, blue: 0.30)),
        InkColor(name: "Fialová", color: Color(red: 0.78, green: 0.62, blue: 1.0))
    ]

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 6) {
                highlightMenu
                fontMenu
                colorMenu
                alignmentButton
                sizeMenu
                voiceButton
                Button(action: onDone) { icon("keyboard.chevron.compact.down") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Skryť klávesnicu")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .sensoryFeedback(.selection, trigger: size)
        .sensoryFeedback(.selection, trigger: alignment)
    }

    // MARK: Highlight / underline
    private var highlightMenu: some View {
        Menu {
            Button { apply { $0.underlineStyle = .single } } label: { Label("Podčiarknuť", systemImage: "underline") }
            Button { apply { $0.backgroundColor = Color.yellow.opacity(0.35) } } label: { Label("Zvýrazniť žltou", systemImage: "highlighter") }
            Button { apply { $0.backgroundColor = Color.pink.opacity(0.35) } } label: { Label("Zvýrazniť ružovou", systemImage: "highlighter") }
            Button { apply { $0.backgroundColor = Color.green.opacity(0.35) } } label: { Label("Zvýrazniť zelenou", systemImage: "highlighter") }
            Divider()
            Button(role: .destructive) {
                apply {
                    $0.underlineStyle = nil
                    $0.backgroundColor = nil
                }
            } label: { Label("Zrušiť zvýraznenie", systemImage: "xmark") }
        } label: { icon("highlighter") }
    }

    // MARK: Font
    private var fontMenu: some View {
        Menu {
            fontButton("Štandardný", .default)
            fontButton("Pätkový", .serif)
            fontButton("Zaoblený", .rounded)
            fontButton("Strojopis", .monospaced)
            Divider()
            Toggle(isOn: Binding(get: { isBold }, set: { isBold = $0; applyFont() })) {
                Label("Tučné", systemImage: "bold")
            }
        } label: { icon("textformat") }
    }

    private func fontButton(_ name: String, _ value: Font.Design) -> some View {
        Button {
            design = value
            applyFont()
        } label: {
            if design == value { Label(name, systemImage: "checkmark") } else { Text(name) }
        }
    }

    // MARK: Colour
    private var colorMenu: some View {
        Menu {
            ForEach(inks) { ink in
                Button { apply { $0.foregroundColor = ink.color } } label: {
                    Label(ink.name, systemImage: "circle.fill")
                }
                .tint(ink.color ?? NoteStyle.ink)
            }
        } label: { icon("paintpalette") }
    }

    // MARK: Alignment
    private var alignmentButton: some View {
        Button {
            switch alignment {
            case .leading: alignment = .center
            case .center: alignment = .trailing
            default: alignment = .leading
            }
            let chosen: AttributedString.TextAlignment = switch alignment {
            case .center: .center
            case .trailing: .right
            default: .left
            }
            apply { $0.alignment = chosen }
        } label: {
            icon(alignmentIcon)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Zarovnanie textu")
    }

    private var alignmentIcon: String {
        switch alignment {
        case .center: return "text.aligncenter"
        case .trailing: return "text.alignright"
        default: return "text.alignleft"
        }
    }

    // MARK: Size
    private var sizeMenu: some View {
        Menu {
            ForEach(NoteStyle.sizes, id: \.self) { value in
                Button {
                    size = value
                    applyFont()
                } label: {
                    if size == value { Label("\(Int(value)) pt", systemImage: "checkmark") } else { Text("\(Int(value)) pt") }
                }
            }
        } label: { icon("textformat.size") }
    }

    // MARK: Voice note
    /// Records a voice note into the text, exactly where the cursor is; tapped again it stops.
    private var voiceButton: some View {
        Button(action: onVoice) {
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(isRecording ? .white : Color.obsidian900)
                .frame(width: 38, height: 38)
                .background(isRecording ? Color.latinRed : Color.gold400, in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.pressable(scale: 0.88))
        .sensoryFeedback(.impact(weight: .medium), trigger: isRecording)
        .accessibilityLabel(isRecording ? "Zastaviť hlasovku" : "Nahrať hlasovku do textu")
    }

    // MARK: Helpers
    private func icon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 42, height: 40)
            .contentShape(Rectangle())
    }

    private func applyFont() {
        apply { $0.font = .system(size: size, weight: isBold ? .bold : .regular, design: design) }
    }

    private func apply(_ change: (inout AttributeContainer) -> Void) {
        onFormat(change)
    }
}
