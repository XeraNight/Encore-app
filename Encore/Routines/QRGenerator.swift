import SwiftUI
import CoreImage.CIFilterBuiltins

/// The QR picture for a link (the member card and a guest coach key).
struct QRGenerator {
    /// Runs off the main thread. Returns nil when the text does not fit into a QR code
    /// (about 2.9 kB with the lowest error correction).
    nonisolated static func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "L"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Upscale the QR image (it's naturally small/pixelated)
        let scaleX = 300.0 / outputImage.extent.size.width
        let scaleY = 300.0 / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        if let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
