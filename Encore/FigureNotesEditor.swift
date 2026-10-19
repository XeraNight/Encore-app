import Combine
import SwiftUI
import UIKit

// MARK: - Figure notes editor
/// The notes of a figure, editable, with voice notes inside the text: the mic in the format bar records
/// exactly where the cursor is. UIKit's text view (TextKit 2) can hold a live view inside the text, which
/// SwiftUI's TextEditor cannot. The note itself stays the SwiftUI AttributedString it always was
/// (`RichNote`); this view only shows and edits it, so old notes open unchanged.
struct FigureNotesEditor: UIViewRepresentable {
    @Binding var text: AttributedString
    @Binding var isEditing: Bool
    let controller: NoteEditorController

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> NotesTextView {
        let view = NotesTextView(usingTextLayoutManager: true)
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

        func textViewDidChange(_ textView: UITextView) { parent.controller.edited() }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if !parent.isEditing { parent.isEditing = true }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.isEditing { parent.isEditing = false }
        }
    }
}

/// A tap on a voice note plays it; it must not also move the cursor and open the keyboard.
final class NotesTextView: UITextView {
    static let voiceTokenIdentifier = "encore.voiceToken"

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
        if let found { storage.deleteCharacters(in: found) }
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

/// One voice note inside the text, drawn by a live SwiftUI view (`InlineVoiceToken`).
nonisolated final class VoiceTextAttachment: NSTextAttachment {
    let token: VoiceTokenModel
    let player: VoiceNotePlayer
    let onStopRecording: () -> Void

    init(token: VoiceTokenModel, player: VoiceNotePlayer, onStopRecording: @escaping () -> Void) {
        self.token = token
        self.player = player
        self.onStopRecording = onStopRecording
        super.init(data: nil, ofType: nil)
        allowsTextAttachmentView = true
    }

    required init?(coder: NSCoder) { nil }

    override func viewProvider(for parentView: UIView?, location: any NSTextLocation,
                               textContainer: NSTextContainer?) -> NSTextAttachmentViewProvider? {
        let provider = VoiceAttachmentViewProvider(textAttachment: self, parentView: parentView,
                                                   textLayoutManager: textContainer?.textLayoutManager, location: location)
        provider.tracksTextAttachmentViewBounds = true
        return provider
    }

    override func attachmentBounds(for attributes: [NSAttributedString.Key: Any], location: any NSTextLocation,
                                   textContainer: NSTextContainer?, proposedLineFragment: CGRect,
                                   position: CGPoint) -> CGRect {
        CGRect(x: 0, y: -8, width: InlineVoiceToken.size.width, height: InlineVoiceToken.size.height)
    }
}

nonisolated private final class VoiceAttachmentViewProvider: NSTextAttachmentViewProvider {
    private var host: UIViewController?

    override func loadView() {
        guard let attachment = textAttachment as? VoiceTextAttachment else { return }
        MainActor.assumeIsolated {
            let controller = UIHostingController(rootView: AttachmentVoiceToken(
                token: attachment.token, player: attachment.player, onStopRecording: attachment.onStopRecording))
            controller.view.backgroundColor = .clear
            controller.view.accessibilityIdentifier = NotesTextView.voiceTokenIdentifier
            host = controller
            view = controller.view
        }
    }
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
