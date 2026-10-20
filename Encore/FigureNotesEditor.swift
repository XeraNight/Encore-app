import Combine
import SwiftUI
import UIKit

// MARK: - Figure notes editor
/// The notes of a figure, editable, with voice notes inside the text: the mic in the format bar records
/// exactly where the cursor is. A voice note keeps an empty space in the text (an attachment) and a live
/// SwiftUI view lies exactly over it, which SwiftUI's TextEditor cannot do. TextKit 1 on purpose: TextKit 2
/// silently falls back to it with attachments, drew a blank file icon and reset the text while typing.
/// The note itself stays the SwiftUI AttributedString it always was (`RichNote`); this view only shows and
/// edits it, so old notes open unchanged.
struct FigureNotesEditor: UIViewRepresentable {
    @Binding var text: AttributedString
    @Binding var isEditing: Bool
    let controller: NoteEditorController

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> NotesTextView {
        let view = NotesTextView.make()
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        view.textContainer.lineFragmentPadding = 5
        view.tintColor = UIColor(Color.gold400)
        view.keyboardAppearance = .dark
        view.adjustsFontForContentSizeCategory = false
        view.delegate = context.coordinator
        view.attributedText = NoteTextBridge.attributed(text, controller: controller)
        view.typingAttributes = NoteTextBridge.uikit(AttributeContainer())
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        context.coordinator.lastModel = text
        controller.attach(view) { [weak coordinator = context.coordinator] model in coordinator?.modelChanged(model) }
        return view
    }

    func updateUIView(_ view: NotesTextView, context: Context) {
        context.coordinator.parent = self
        // Changed from elsewhere (partner, coach, a correction) while not typing.
        if text != context.coordinator.lastModel, !view.isFirstResponder {
            view.attributedText = NoteTextBridge.attributed(text, controller: controller)
            context.coordinator.lastModel = text
            view.setNeedsLayout()
        }
        if isEditing, !view.isFirstResponder {
            DispatchQueue.main.async { view.becomeFirstResponder() }
        } else if !isEditing, view.isFirstResponder {
            DispatchQueue.main.async { view.resignFirstResponder() }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: NotesTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 320
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(fitted.height, 180))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: FigureNotesEditor
        var lastModel = AttributedString()

        init(parent: FigureNotesEditor) { self.parent = parent }

        func modelChanged(_ model: AttributedString) {
            lastModel = model
            if parent.text != model { parent.text = model }
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.controller.edited()
            textView.setNeedsLayout()
            reveal(textView)
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard textView.isFirstResponder else { return }
            reveal(textView)
        }

        /// The text view does not scroll itself, so the page scrolls to keep the cursor above the keyboard,
        /// once the new height has been laid out.
        private func reveal(_ textView: UITextView) {
            DispatchQueue.main.async {
                guard let end = textView.selectedTextRange?.end else { return }
                var ancestor = textView.superview
                while let view = ancestor, !(view is UIScrollView) { ancestor = view.superview }
                guard let page = ancestor as? UIScrollView else { return }
                let caret = textView.caretRect(for: end).insetBy(dx: 0, dy: -28)
                page.scrollRectToVisible(textView.convert(caret, to: page), animated: true)
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if !parent.isEditing { parent.isEditing = true }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.isEditing { parent.isEditing = false }
        }
    }
}

/// Lays the live voice views over the spaces their attachments keep in the text. A tap on a voice note plays
/// it; it must not also move the cursor and open the keyboard.
final class NotesTextView: UITextView {
    static let voiceTokenIdentifier = "encore.voiceToken"
    private var tokenHosts: [ObjectIdentifier: UIHostingController<AttachmentVoiceToken>] = [:]
    /// The text view holds only the container; the storage must stay alive with it.
    private var ownedStorage: NSTextStorage?

    /// TextKit 1 built by hand through the designated initializer. `UITextView(usingTextLayoutManager:)` is a
    /// factory that skips this subclass's own properties, and the first layout then crashed.
    static func make() -> NotesTextView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        let view = NotesTextView(frame: .zero, textContainer: container)
        view.ownedStorage = storage
        return view
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutVoiceTokens()
    }

    private func layoutVoiceTokens() {
        layoutManager.ensureLayout(for: textContainer)
        var present = Set<ObjectIdentifier>()
        textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textStorage.length)) { value, range, _ in
            guard let attachment = value as? VoiceTextAttachment else { return }
            let id = ObjectIdentifier(attachment)
            present.insert(id)
            let host = tokenHosts[id] ?? makeHost(for: attachment, id: id)
            host.view.frame = frame(ofCharacterAt: range.location, bounds: attachment.bounds)
        }
        for (id, host) in tokenHosts where !present.contains(id) {
            host.view.removeFromSuperview()
            tokenHosts[id] = nil
        }
    }

    private func makeHost(for attachment: VoiceTextAttachment, id: ObjectIdentifier) -> UIHostingController<AttachmentVoiceToken> {
        let host = UIHostingController(rootView: AttachmentVoiceToken(
            token: attachment.token, player: attachment.player, onStopRecording: attachment.onStopRecording))
        host.view.backgroundColor = .clear
        host.view.accessibilityIdentifier = Self.voiceTokenIdentifier
        addSubview(host.view)
        tokenHosts[id] = host
        return host
    }

    /// Where the attachment sits: its line, its place on the baseline and its own bounds (y up from the baseline).
    private func frame(ofCharacterAt index: Int, bounds: CGRect) -> CGRect {
        let glyph = layoutManager.glyphIndexForCharacter(at: index)
        let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let baseline = layoutManager.location(forGlyphAt: glyph)
        return CGRect(x: textContainerInset.left + line.minX + baseline.x,
                      y: textContainerInset.top + line.minY + baseline.y - bounds.maxY,
                      width: bounds.width, height: bounds.height)
    }

    override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        var view = hitTest(recognizer.location(in: self), with: nil)
        while let current = view, current !== self {
            if current.accessibilityIdentifier == Self.voiceTokenIdentifier { return false }
            view = current.superview
        }
        return super.gestureRecognizerShouldBegin(recognizer)
    }
}

// MARK: - Controller
/// Owns the text view while the figure is open: formatting from the bar and recording into the text.
@MainActor
final class NoteEditorController: ObservableObject {
    @Published private(set) var isRecording = false
    @Published var errorMessage: String?
    let player = VoiceNotePlayer()
    /// Every recording made here, so the ones deleted from the text can be removed from the phone.
    private(set) var recordedFiles: Set<String> = []

    private let recorder = VoiceNoteRecorder()
    private weak var textView: NotesTextView?
    private var onEdit: ((AttributedString) -> Void)?
    private var recording: (token: VoiceTokenModel, attachment: VoiceTextAttachment)?
    private var lastSample: TimeInterval = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Four bars a second, the same scale the saved waveform uses, so the carousel moves the same way.
        recorder.$elapsed
            .sink { [weak self] elapsed in
                guard let self, let token = self.recording?.token else { return }
                token.elapsed = elapsed
                guard elapsed - self.lastSample >= 0.25 else { return }
                self.lastSample = elapsed
                token.liveLevels.append(self.recorder.level)
                if token.liveLevels.count > 60 { token.liveLevels.removeFirst(token.liveLevels.count - 60) }
            }
            .store(in: &cancellables)
    }

    fileprivate func attach(_ view: NotesTextView, onEdit: @escaping (AttributedString) -> Void) {
        textView = view
        self.onEdit = onEdit
    }

    /// The text view changed: the note follows.
    func edited() {
        guard let textView else { return }
        onEdit?(NoteTextBridge.model(from: textView.attributedText))
    }

    /// Formatting from the bar, for the selected words or for what is typed next.
    func apply(_ change: (inout AttributeContainer) -> Void) {
        guard let textView else { return }
        let range = textView.selectedRange
        guard range.length > 0 else {
            var attributes = (textView.typingAttributes[.encoreRun] as? RunAttributes)?.value ?? AttributeContainer()
            change(&attributes)
            textView.typingAttributes = NoteTextBridge.uikit(attributes)
            return
        }
        // Alignment belongs to whole paragraphs.
        var probe = AttributeContainer()
        change(&probe)
        let target = probe.alignment != nil
            ? (textView.textStorage.string as NSString).paragraphRange(for: range)
            : range
        let storage = textView.textStorage
        storage.beginEditing()
        storage.enumerateAttributes(in: target) { attributes, part, _ in
            guard attributes[.attachment] == nil else { return }
            var container = (attributes[.encoreRun] as? RunAttributes)?.value ?? AttributeContainer()
            change(&container)
            storage.setAttributes(NoteTextBridge.uikit(container), range: part)
        }
        storage.endEditing()
        textView.selectedRange = range
        textView.setNeedsLayout()
        edited()
    }

    // MARK: Recording
    func toggleRecording() {
        if isRecording { stopRecording() } else { Task { await startRecording() } }
    }

    private func startRecording() async {
        guard let textView, !isRecording else { return }
        errorMessage = nil
        player.stop()
        await recorder.start()
        guard recorder.state == .recording else {
            errorMessage = recorder.errorMessage
            return
        }
        let token = VoiceTokenModel(ref: nil)
        let attachment = VoiceTextAttachment(token: token, player: player) { [weak self] in self?.stopRecording() }
        recording = (token, attachment)
        lastSample = 0
        let selection = textView.selectedRange
        let location = selection.location + selection.length
        let typing = textView.typingAttributes
        textView.textStorage.insert(NSAttributedString(attachment: attachment), at: location)
        textView.selectedRange = NSRange(location: location + 1, length: 0)
        textView.typingAttributes = typing
        textView.setNeedsLayout()
        isRecording = true
    }

    /// The recording becomes a voice note in the text; a recording too short to keep disappears.
    func stopRecording() {
        guard isRecording, let current = recording else { return }
        recorder.stop()
        isRecording = false
        recording = nil
        if let result = recorder.takeResult() {
            current.token.ref = VoiceNoteRef(fileName: result.fileName, duration: result.duration)
            recordedFiles.insert(result.fileName)
        } else {
            remove(current.attachment)
        }
        edited()
    }

    private func remove(_ attachment: VoiceTextAttachment) {
        guard let storage = textView?.textStorage else { return }
        var found: NSRange?
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, stop in
            if (value as AnyObject) === attachment {
                found = range
                stop.pointee = true
            }
        }
        if let found {
            storage.deleteCharacters(in: found)
            textView?.setNeedsLayout()
        }
    }
}

// MARK: - Voice note in the text
/// What a voice note in the editor shows: recording (live levels) or a saved note.
@MainActor
final class VoiceTokenModel: ObservableObject {
    @Published var ref: VoiceNoteRef?
    @Published var liveLevels: [CGFloat] = []
    @Published var elapsed: TimeInterval = 0

    init(ref: VoiceNoteRef?) { self.ref = ref }
}

/// One voice note inside the text: it keeps a clear space of the token's size; the text view lays the live
/// SwiftUI view (`InlineVoiceToken`) over it.
final class VoiceTextAttachment: NSTextAttachment {
    let token: VoiceTokenModel
    let player: VoiceNotePlayer
    let onStopRecording: () -> Void

    private static let clearImage = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }

    init(token: VoiceTokenModel, player: VoiceNotePlayer, onStopRecording: @escaping () -> Void) {
        self.token = token
        self.player = player
        self.onStopRecording = onStopRecording
        super.init(data: nil, ofType: nil)
        image = Self.clearImage
        // Sits on the line like a word: a little below the baseline, centred on the text.
        bounds = CGRect(x: 0, y: -10, width: InlineVoiceToken.size.width, height: InlineVoiceToken.size.height)
    }

    required init?(coder: NSCoder) { nil }
}

private struct AttachmentVoiceToken: View {
    @ObservedObject var token: VoiceTokenModel
    @ObservedObject var player: VoiceNotePlayer
    let onStopRecording: () -> Void

    var body: some View {
        InlineVoiceToken(ref: token.ref, player: player, liveLevels: token.liveLevels,
                         elapsed: token.elapsed, onStopRecording: onStopRecording)
            .environment(\.colorScheme, .dark)
    }
}

// MARK: - Note ↔ text view
private extension NSAttributedString.Key {
    /// The SwiftUI formatting of a run, kept on the UIKit text so it survives typing and comes back unchanged.
    static let encoreRun = NSAttributedString.Key("encoreNoteRun")
}

private final class RunAttributes: NSObject {
    let value: AttributeContainer
    init(_ value: AttributeContainer) { self.value = value }
}

@MainActor
enum NoteTextBridge {
    /// UIKit attributes that draw a run like SwiftUI would, plus the SwiftUI formatting itself.
    static func uikit(_ attributes: AttributeContainer) -> [NSAttributedString.Key: Any] {
        var result: [NSAttributedString.Key: Any] = [.encoreRun: RunAttributes(attributes)]
        if let font = attributes[AttributeScopes.SwiftUIAttributes.FontAttribute.self] {
            result[.font] = font.resolve(in: EnvironmentValues().fontResolutionContext).ctFont as UIFont
        } else {
            result[.font] = UIFont.systemFont(ofSize: NoteStyle.defaultSize)
        }
        result[.foregroundColor] = UIColor(attributes[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] ?? NoteStyle.ink)
        if let background = attributes[AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] {
            result[.backgroundColor] = UIColor(background)
        }
        if attributes[AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] != nil {
            result[.underlineStyle] = NSUnderlineStyle.single.rawValue
            result[.underlineColor] = result[.foregroundColor]
        }
        let paragraph = NSMutableParagraphStyle()
        switch attributes.alignment {
        case .center: paragraph.alignment = .center
        case .right: paragraph.alignment = .right
        default: paragraph.alignment = .natural
        }
        paragraph.lineSpacing = 3
        result[.paragraphStyle] = paragraph
        return result
    }

    static func attributed(_ model: AttributedString, controller: NoteEditorController) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for run in model.runs {
            if let ref = run.voiceNote {
                result.append(NSAttributedString(attachment: VoiceTextAttachment(
                    token: VoiceTokenModel(ref: ref), player: controller.player, onStopRecording: {})))
            } else {
                result.append(NSAttributedString(string: String(model[run.range].characters), attributes: uikit(run.attributes)))
            }
        }
        return result
    }

    /// Back to the note; a voice note still being recorded is not part of it yet.
    static func model(from text: NSAttributedString) -> AttributedString {
        var result = AttributedString()
        let string = text.string as NSString
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, range, _ in
            if let voice = attributes[.attachment] as? VoiceTextAttachment {
                guard let ref = voice.token.ref else { return }
                var piece = AttributedString(RichNote.voiceCharacter)
                piece.voiceNote = ref
                result.append(piece)
            } else {
                let container = (attributes[.encoreRun] as? RunAttributes)?.value ?? AttributeContainer()
                result.append(AttributedString(string.substring(with: range), attributes: container))
            }
        }
        return result
    }
}
