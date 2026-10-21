import AVFoundation
import Combine
import SwiftUI
import UIKit

// MARK: - Figure notes editor
/// The notes of a figure, editable, with voice notes and videos inside the text: the mic in the format bar
/// records exactly where the cursor is, a video from Denník is a block between paragraphs. Each keeps an empty
/// space in the text (an attachment) and a live SwiftUI view lies exactly over it, which SwiftUI's TextEditor
/// cannot do. TextKit 1 on purpose: TextKit 2
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
            parent.controller.hasCaret = true
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

/// An attachment that keeps a clear space in the text; the text view lays its live SwiftUI view over it.
protocol LiveTextAttachment: NSTextAttachment {
    /// Free space kept around the live view inside the attachment, so it never touches the text.
    var margins: UIEdgeInsets { get }
    func makeHost() -> UIViewController
}

/// Lays the live views (voice notes, videos) over the spaces their attachments keep in the text. A tap on one
/// plays it; it must not also move the cursor and open the keyboard.
final class NotesTextView: UITextView {
    static let voiceTokenIdentifier = "encore.voiceToken"
    static let videoBlockIdentifier = "encore.videoBlock"
    private var hosts: [ObjectIdentifier: UIViewController] = [:]
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
        layoutLiveViews()
    }

    private func layoutLiveViews() {
        layoutManager.ensureLayout(for: textContainer)
        var present = Set<ObjectIdentifier>()
        textStorage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: textStorage.length)) { value, range, _ in
            guard let attachment = value as? any LiveTextAttachment else { return }
            let id = ObjectIdentifier(attachment)
            present.insert(id)
            let host = hosts[id] ?? makeHost(for: attachment, id: id)
            host.view.frame = frame(ofCharacterAt: range.location).inset(by: attachment.margins)
        }
        for (id, host) in hosts where !present.contains(id) {
            host.view.removeFromSuperview()
            hosts[id] = nil
        }
    }

    private func makeHost(for attachment: any LiveTextAttachment, id: ObjectIdentifier) -> UIViewController {
        let host = attachment.makeHost()
        host.view.backgroundColor = .clear
        addSubview(host.view)
        hosts[id] = host
        return host
    }

    /// Where the attachment sits: its line, its place in it and the size the layout gave it. For an attachment
    /// TextKit reports the place of its bottom edge, not the baseline of the text (that put voice notes 10 pt low).
    private func frame(ofCharacterAt index: Int) -> CGRect {
        let glyph = layoutManager.glyphIndexForCharacter(at: index)
        let line = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        let bottom = layoutManager.location(forGlyphAt: glyph)
        let size = layoutManager.attachmentSize(forGlyphAt: glyph)
        return CGRect(x: textContainerInset.left + line.minX + bottom.x,
                      y: textContainerInset.top + line.minY + bottom.y - size.height,
                      width: size.width, height: size.height)
    }

    override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        var view = hitTest(recognizer.location(in: self), with: nil)
        while let current = view, current !== self {
            if let id = current.accessibilityIdentifier, [Self.voiceTokenIdentifier, Self.videoBlockIdentifier].contains(id) {
                return false
            }
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
    let video = NoteVideoPlayer()
    /// A video in the text becomes the figure's video (false) or its model (true).
    var onUseVideo: ((_ path: String, _ asModel: Bool) -> Void)?
    /// Every recording made or placed here (the figure's own copies), so the ones deleted from the text can be
    /// removed from the phone.
    private(set) var recordedFiles: Set<String> = []
    /// The dancer has put the cursor somewhere; otherwise text from Denník goes at the end.
    fileprivate(set) var hasCaret = false

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
        let model = NoteTextBridge.model(from: textView.attributedText)
        // A video deleted from the text stops playing.
        if let playing = video.playingPath, !model.runs.contains(where: { $0.videoNote?.path == playing }) { video.stop() }
        onEdit?(model)
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

    // MARK: From Denník
    /// Text from Denník where the cursor is (at the end on its own line when it never was in the text). It
    /// lights up gold for a moment, so it is clear where it landed.
    func insertText(_ text: String) {
        guard let textView, !text.isEmpty else { return }
        let storage = textView.textStorage
        let selection = textView.selectedRange
        let location = hasCaret ? min(selection.location + selection.length, storage.length) : storage.length
        var string = text
        if !hasCaret, storage.length > 0, !storage.string.hasSuffix("\n") { string = "\n" + string }
        storage.insert(NSAttributedString(string: string, attributes: textView.typingAttributes), at: location)
        let inserted = NSRange(location: location, length: (string as NSString).length)
        textView.selectedRange = NSRange(location: inserted.upperBound, length: 0)
        textView.setNeedsLayout()
        flash(inserted)
        edited()
    }

    /// Where a voice note dropped at this point (window coordinates) would go, and the cursor line there.
    func insertionPoint(nearGlobal point: CGPoint) -> (index: Int, caret: CGRect)? {
        guard let textView else { return nil }
        let local = textView.convert(point, from: nil)
        guard textView.bounds.insetBy(dx: -40, dy: -60).contains(local),
              let position = textView.closestPosition(to: local) else { return nil }
        let index = textView.offset(from: textView.beginningOfDocument, to: position)
        return (index, textView.convert(textView.caretRect(for: position), to: nil))
    }

    /// A voice note from Denník (the figure's own copy of the recording), with the note's text after it.
    func insertVoice(_ ref: VoiceNoteRef, followedBy text: String?, at index: Int) {
        guard let textView else { return }
        let storage = textView.textStorage
        let location = min(max(0, index), storage.length)
        let piece = NSMutableAttributedString(attachment: VoiceTextAttachment(
            token: VoiceTokenModel(ref: ref), player: player, onStopRecording: {}))
        if let text, !text.isEmpty {
            piece.append(NSAttributedString(string: " " + text, attributes: textView.typingAttributes))
        }
        storage.insert(piece, at: location)
        recordedFiles.insert(ref.fileName)
        let inserted = NSRange(location: location, length: piece.length)
        textView.selectedRange = NSRange(location: inserted.upperBound, length: 0)
        textView.setNeedsLayout()
        flash(inserted)
        edited()
    }

    /// Where a video dropped at this point (window coordinates) would go: the nearer edge of the paragraph
    /// under it, and the line across the text there.
    func blockInsertionPoint(nearGlobal point: CGPoint) -> (index: Int, line: CGRect)? {
        guard let textView, let (index, _) = insertionPoint(nearGlobal: point) else { return nil }
        let string = textView.textStorage.string as NSString
        let paragraph = string.paragraphRange(for: NSRange(location: min(index, string.length), length: 0))
        let local = textView.convert(point, from: nil)
        let edges = [paragraph.location, paragraph.upperBound].map { edge in (edge, lineY(before: edge, in: textView)) }
        guard let nearest = edges.min(by: { abs($0.1 - local.y) < abs($1.1 - local.y) }) else { return nil }
        let inset = textView.textContainerInset.left + textView.textContainer.lineFragmentPadding
        let line = CGRect(x: inset, y: nearest.1 - 1.5, width: textView.bounds.width - 2 * inset, height: 3)
        return (nearest.0, textView.convert(line, to: nil))
    }

    /// Height in the text view where a block put at this index would start.
    private func lineY(before index: Int, in textView: UITextView) -> CGFloat {
        guard let position = textView.position(from: textView.beginningOfDocument, offset: index) else { return 0 }
        let caret = textView.caretRect(for: position)
        let string = textView.textStorage.string
        let afterLastLine = index == (string as NSString).length && !string.isEmpty && !string.hasSuffix("\n")
        return afterLastLine ? caret.maxY + 4 : caret.minY - 2
    }

    /// A video from Denník as a block of its own between paragraphs, with the note's text after it.
    func insertVideo(_ ref: VideoNoteRef, followedBy text: String?, at index: Int) {
        guard let textView else { return }
        let storage = textView.textStorage
        let location = min(max(0, index), storage.length)
        let string = storage.string as NSString
        let newline = NSAttributedString(string: "\n", attributes: textView.typingAttributes)
        let piece = NSMutableAttributedString()
        if location > 0, string.character(at: location - 1) != 10 { piece.append(newline) }
        piece.append(NSAttributedString(attachment: VideoTextAttachment(ref: ref, controller: self)))
        piece.append(newline)
        if let text, !text.isEmpty {
            piece.append(NSAttributedString(string: text, attributes: textView.typingAttributes))
            if location < storage.length, string.character(at: location) != 10 { piece.append(newline) }
        }
        storage.insert(piece, at: location)
        textView.selectedRange = NSRange(location: location + piece.length, length: 0)
        textView.setNeedsLayout()
        if let text, !text.isEmpty {
            flash(NSRange(location: location + piece.length - (text as NSString).length, length: (text as NSString).length))
        }
        edited()
    }

    /// "Odstrániť z poznámok" on a video; the video itself stays where it was (Denník, Fotky).
    fileprivate func removeVideo(_ attachment: VideoTextAttachment) {
        if video.playingPath == attachment.ref.path { video.stop() }
        remove(attachment)
        edited()
    }

    /// A short gold glow on what was just put in; drawn only, never saved with the note.
    private func flash(_ range: NSRange) {
        guard let textView else { return }
        let glow = UIColor(Color.gold400).withAlphaComponent(0.35)
        textView.textStorage.addAttribute(.backgroundColor, value: glow, range: range)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak textView] in
            guard let textView else { return }
            let safe = NSIntersectionRange(range, NSRange(location: 0, length: textView.textStorage.length))
            guard safe.length > 0 else { return }
            UIView.transition(with: textView, duration: 0.6, options: .transitionCrossDissolve) {
                // Back to how the note itself looks (a highlight chosen by the dancer stays).
                let storage = textView.textStorage
                storage.enumerateAttributes(in: safe) { attributes, part, _ in
                    guard attributes[.attachment] == nil else {
                        storage.removeAttribute(.backgroundColor, range: part)
                        return
                    }
                    let container = (attributes[.encoreRun] as? RunAttributes)?.value ?? AttributeContainer()
                    storage.setAttributes(NoteTextBridge.uikit(container), range: part)
                }
            }
        }
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

    private func remove(_ attachment: NSTextAttachment) {
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

private extension UIImage {
    /// What an attachment draws: nothing (without an image TextKit draws a file icon).
    static let clearSpace = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
}

/// One voice note inside the text: it keeps a clear space of the token's size; the text view lays the live
/// SwiftUI view (`InlineVoiceToken`) over it.
final class VoiceTextAttachment: NSTextAttachment, LiveTextAttachment {
    let token: VoiceTokenModel
    let player: VoiceNotePlayer
    let onStopRecording: () -> Void

    init(token: VoiceTokenModel, player: VoiceNotePlayer, onStopRecording: @escaping () -> Void) {
        self.token = token
        self.player = player
        self.onStopRecording = onStopRecording
        super.init(data: nil, ofType: nil)
        image = .clearSpace
    }

    required init?(coder: NSCoder) { nil }

    nonisolated private static let space = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)

    var margins: UIEdgeInsets { Self.space }

    /// Sits on the line like a word, centred on the letters of the text around it (a heading too), with a
    /// little air all round so it touches neither its neighbours nor the lines above and below.
    nonisolated override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect,
                                               glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        let font = Self.font(near: charIndex, in: textContainer?.layoutManager?.textStorage)
        let size = CGSize(width: InlineVoiceToken.size.width + Self.space.left + Self.space.right,
                          height: InlineVoiceToken.size.height + Self.space.top + Self.space.bottom)
        return CGRect(x: 0, y: font.capHeight / 2 - size.height / 2, width: size.width, height: size.height)
    }

    /// The font of the words next to the voice note (the attachment itself has none).
    nonisolated private static func font(near index: Int, in storage: NSTextStorage?) -> UIFont {
        guard let storage else { return .systemFont(ofSize: NoteStyle.defaultSize) }
        for candidate in [index - 1, index + 1] where candidate >= 0 && candidate < storage.length {
            if let font = storage.attribute(.font, at: candidate, effectiveRange: nil) as? UIFont { return font }
        }
        return .systemFont(ofSize: NoteStyle.defaultSize)
    }

    func makeHost() -> UIViewController {
        let host = UIHostingController(rootView: AttachmentVoiceToken(token: token, player: player, onStopRecording: onStopRecording))
        host.view.accessibilityIdentifier = NotesTextView.voiceTokenIdentifier
        return host
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

// MARK: - Video in the text
/// One video inside the text: a block across the text (narrow and tall when filmed upright) keeping a clear
/// space; the text view lays the live view (`AttachmentVideoBlock`) over it.
final class VideoTextAttachment: NSTextAttachment, LiveTextAttachment {
    nonisolated let ref: VideoNoteRef
    private let video: NoteVideoPlayer
    private weak var controller: NoteEditorController?

    nonisolated static let maxHeight: CGFloat = 260
    /// Air above and below the video inside its block.
    nonisolated static let gap: CGFloat = 6

    init(ref: VideoNoteRef, controller: NoteEditorController) {
        self.ref = ref
        self.video = controller.video
        self.controller = controller
        super.init(data: nil, ofType: nil)
        image = .clearSpace
    }

    required init?(coder: NSCoder) { nil }

    /// The whole width of the text, so the block always has a line of its own.
    nonisolated override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect,
                                               glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        let width = max(60, lineFrag.width - 2 * (textContainer?.lineFragmentPadding ?? 0))
        return CGRect(x: 0, y: 0, width: width, height: Self.videoSize(isPortrait: ref.isPortrait, width: width).height + 2 * Self.gap)
    }

    /// Landscape fills the width (at most 260 high); upright is 260 high and about half the width.
    nonisolated static func videoSize(isPortrait: Bool, width: CGFloat) -> CGSize {
        if isPortrait { return CGSize(width: min(width, maxHeight * 9 / 16), height: maxHeight) }
        let height = min(maxHeight, width * 9 / 16)
        return CGSize(width: height * 16 / 9, height: height)
    }

    var margins: UIEdgeInsets { .zero }

    func makeHost() -> UIViewController {
        let host = UIHostingController(rootView: AttachmentVideoBlock(
            ref: ref, video: video,
            onUse: { [weak self] asModel in
                guard let self else { return }
                self.controller?.onUseVideo?(self.ref.path, asModel)
            },
            onRemove: { [weak self] in
                guard let self else { return }
                self.controller?.removeVideo(self)
            }))
        host.view.accessibilityIdentifier = NotesTextView.videoBlockIdentifier
        return host
    }
}

/// A video inside the text: its first frame with a play button. A tap plays it in place, silent and looping;
/// a long press makes it the figure's video or the model, or takes it out of the notes.
private struct AttachmentVideoBlock: View {
    let ref: VideoNoteRef
    @ObservedObject var video: NoteVideoPlayer
    let onUse: (_ asModel: Bool) -> Void
    let onRemove: () -> Void

    @State private var appeared = false

    private var isPlaying: Bool { video.playingPath == ref.path }

    var body: some View {
        GeometryReader { geo in
            let size = VideoTextAttachment.videoSize(isPortrait: ref.isPortrait, width: geo.size.width)
            block
                .frame(width: size.width, height: size.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .scaleEffect(appeared ? 1 : 0.92, anchor: .leading)
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { appeared = true } }
        .environment(\.colorScheme, .dark)
    }

    private var block: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return ZStack {
            if isPlaying, let player = video.player {
                CustomAVPlayerRepresentable(player: player, gravity: .resizeAspectFill)
                    .transition(.opacity)
            } else {
                MediaThumbnailView(path: ref.path, cornerRadius: 0)
                if video.missingPath == ref.path {
                    Label("Video sa nenašlo", systemImage: "video.slash.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(8)
                        .background(Color.black.opacity(0.55), in: Capsule())
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.obsidian900)
                        .frame(width: 44, height: 44)
                        .background(Color.gold400, in: Circle())
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
                }
            }
        }
        .clipShape(shape)
        .overlay(shape.stroke(Color.gold400.opacity(isPlaying ? 0.7 : 0.3), lineWidth: 1))
        .overlay(alignment: .topLeading) {
            Text("VIDEO")
                .font(.system(.caption2, design: .rounded).weight(.black))
                .tracking(1.2)
                .foregroundColor(Color.gold400)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.45), in: Capsule())
                .padding(8)
        }
        .animation(.easeInOut(duration: 0.25), value: isPlaying)
        .contentShape(shape)
        .onTapGesture { video.toggle(ref.path) }
        .contextMenu {
            Button { onUse(false) } label: { Label("Ako moje video", systemImage: "person.fill") }
            Button { onUse(true) } label: { Label("Ako vzor", systemImage: "star.fill") }
            Divider()
            Button(role: .destructive, action: onRemove) { Label("Odstrániť z poznámok", systemImage: "trash") }
        }
        .sensoryFeedback(.selection, trigger: isPlaying)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Video v poznámkach")
        .accessibilityHint(isPlaying ? "Ťuknutím zastavíš" : "Ťuknutím prehráš")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Ako moje video") { onUse(false) }
        .accessibilityAction(named: "Ako vzor") { onUse(true) }
        .accessibilityAction(named: "Odstrániť z poznámok", onRemove)
    }
}

/// The one video playing inside the notes: silent and looping. It takes the audio session only when nothing
/// else holds it, so music in the hall plays on and a figure video with sound keeps its sound.
@MainActor
final class NoteVideoPlayer: ObservableObject {
    @Published private(set) var playingPath: String?
    @Published private(set) var missingPath: String?
    private(set) var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var request = 0

    func toggle(_ path: String) {
        let wasPlaying = playingPath == path
        stop()
        guard !wasPlaying else { return }
        let current = request
        Task {
            guard let url = await MediaResolver.videoURL(path: path) else {
                if current == request { missingPath = path }
                return
            }
            if await AudioSessionCoordinator.shared.currentClient == nil {
                try? await AudioSessionCoordinator.shared.activate(.mutedVideo)
            }
            guard current == request else { return }
            let queue = AVQueuePlayer()
            queue.isMuted = true
            looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
            player = queue
            missingPath = nil
            playingPath = path
            queue.play()
        }
    }

    func stop() {
        request += 1
        player?.pause()
        looper = nil
        player = nil
        playingPath = nil
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
            } else if let ref = run.videoNote {
                result.append(NSAttributedString(attachment: VideoTextAttachment(ref: ref, controller: controller)))
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
                result.append(NoteMedia.voice(ref).piece)
            } else if let video = attributes[.attachment] as? VideoTextAttachment {
                result.append(NoteMedia.video(video.ref).piece)
            } else {
                let container = (attributes[.encoreRun] as? RunAttributes)?.value ?? AttributeContainer()
                result.append(AttributedString(string.substring(with: range), attributes: container))
            }
        }
        return result
    }
}
