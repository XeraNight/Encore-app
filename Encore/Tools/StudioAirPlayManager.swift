import SwiftUI
import AVKit

// MARK: - AirPlay Route Picker Representable
struct AirPlayRoutePickerRepresentable: UIViewRepresentable {
    var tintColor: UIColor = .white
    var activeTintColor: UIColor = UIColor(Color.amberGold)
    
    init(tintColor: UIColor = .white, activeTintColor: UIColor = UIColor(Color.amberGold)) {
        self.tintColor = tintColor
        self.activeTintColor = activeTintColor
    }
    
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = tintColor
        picker.activeTintColor = activeTintColor
        picker.prioritizesVideoDevices = true
        return picker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tintColor
        uiView.activeTintColor = activeTintColor
    }
}
