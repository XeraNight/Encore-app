import SwiftUI
import UIKit

/// A photo on the whole screen: two fingers zoom, a double tap zooms in and back, a swipe down or "Zavrieť" closes it.
/// Presented from UIKit so it also works from the text of a figure's notes.
@MainActor
enum FullScreenPhoto {
    static func present(path: String) {
        guard let image = MediaResolver.resolveImage(path: path, maxPixelSize: 3000),
              let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              var top = scene.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }
        let host = UIHostingController(rootView: PhotoViewer(image: image) { [weak top] in top?.dismiss(animated: true) })
        host.modalPresentationStyle = .fullScreen
        host.view.backgroundColor = .black
        top.present(host, animated: true)
    }
}

private struct PhotoViewer: View {
    let image: UIImage
    let onClose: () -> Void

    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .gesture(zoom)
                .simultaneousGesture(scale > 1 ? pan : nil)
                .onTapGesture(count: 2) { toggleZoom() }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 30).onEnded { value in
                        if scale <= 1, value.translation.height > 90 { onClose() }
                    }
                )
                .accessibilityLabel("Fotka")
            Button(action: onClose) {
                Text("Zavrieť")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .glassEffect(.regular.interactive(), in: Capsule())
            }
            .padding(16)
        }
        .preferredColorScheme(.dark)
    }

    private var zoom: some Gesture {
        MagnifyGesture()
            .onChanged { scale = min(max(baseScale * $0.magnification, 1), 5) }
            .onEnded { _ in
                baseScale = scale
                if scale <= 1 { reset() }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .onChanged { offset = CGSize(width: baseOffset.width + $0.translation.width, height: baseOffset.height + $0.translation.height) }
            .onEnded { _ in baseOffset = offset }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if scale > 1 { reset() } else { scale = 2.5; baseScale = 2.5 }
        }
    }

    private func reset() {
        scale = 1; baseScale = 1; offset = .zero; baseOffset = .zero
    }
}
