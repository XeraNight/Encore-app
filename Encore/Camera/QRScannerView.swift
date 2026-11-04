import SwiftUI
import AVFoundation

struct QRScannerView: ViewModifier {
    @Binding var isPresented: Bool
    var onScan: (String) -> Void
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                QRScannerRepresentable(
                    onScan: { code in
                        onScan(code)
                        isPresented = false
                    },
                    onCancel: {
                        isPresented = false
                    }
                )
                .ignoresSafeArea()
            }
    }
}

extension View {
    func qrScanner(isPresented: Binding<Bool>, onScan: @escaping (String) -> Void) -> some View {
        self.modifier(QRScannerView(isPresented: isPresented, onScan: onScan))
    }
}

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    var onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, QRScannerViewControllerDelegate {
        let parent: QRScannerRepresentable
        
        init(parent: QRScannerRepresentable) {
            self.parent = parent
        }
        
        func qrScannerDidScan(code: String) {
            parent.onScan(code)
        }
        
        func qrScannerDidCancel() {
            parent.onCancel()
        }
    }
}

private protocol QRScannerViewControllerDelegate: AnyObject {
    func qrScannerDidScan(code: String)
    func qrScannerDidCancel()
}

private class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: QRScannerViewControllerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "com.encore.qrScanner.session", qos: .userInitiated)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        #if targetEnvironment(simulator)
        // Simulator debug helper
        let label = UILabel()
        label.text = "Simulátor nepodporuje kameru.\nKlikni na tlačidlo pre simuláciu skenu."
        label.numberOfLines = 0
        label.textColor = .white
        label.textAlignment = .center
        label.frame = CGRect(x: 20, y: 150, width: view.frame.width - 40, height: 100)
        view.addSubview(label)
        
        let button = UIButton(type: .system)
        button.setTitle("Simulovať import zostavy", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.85, green: 0.45, blue: 0.35, alpha: 1.0)
        button.layer.cornerRadius = 12
        button.frame = CGRect(x: 40, y: 300, width: view.frame.width - 80, height: 50)
        button.addTarget(self, action: #selector(simulateScan), for: .touchUpInside)
        view.addSubview(button)
        #else
        checkPermissionAndSetupCamera()
        #endif
        
        setupCancelButton()
    }
    
    @objc private func simulateScan() {
        let dummyPayload = """
        {"n":"Simulovaná zostava z QR","d":"Waltz","c":"Standard","nodes":[{"x":200,"y":300,"f":"Natural Spin Turn","r":"1, 2, 3, 4, 5, 6","o":0,"n":"Dôležité točiť na pätách.","t":""},{"x":450,"y":300,"f":"Chasse from PP","r":"1, 2 a 3","o":1,"n":"Ramená držať dole.","t":"Prechod na stred sály"}]}
        """
        delegate?.qrScannerDidScan(code: dummyPayload)
    }
    
    private func checkPermissionAndSetupCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.setupCamera() : self?.showCameraMessage("Prístup ku kamere bol odmietnutý.")
                }
            }
        case .denied, .restricted:
            showCameraMessage("Prístup ku kamere je zakázaný.\nPovoľ ho v Nastavenia → Encore.")
        @unknown default:
            setupCamera()
        }
    }
    
    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            
            let session = AVCaptureSession()
            session.beginConfiguration()
            session.sessionPreset = session.canSetSessionPreset(.high) ? .high : .medium
            
            guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
                  let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
                  session.canAddInput(videoInput) else {
                session.commitConfiguration()
                DispatchQueue.main.async { self.showCameraMessage("Kamera nie je dostupná.") }
                return
            }
            session.addInput(videoInput)
            
            let metadataOutput = AVCaptureMetadataOutput()
            guard session.canAddOutput(metadataOutput) else {
                session.commitConfiguration()
                DispatchQueue.main.async { self.showCameraMessage("QR skener nie je dostupný.") }
                return
            }
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
            session.commitConfiguration()
            
            DispatchQueue.main.async {
                self.captureSession = session
                
                let preview = AVCaptureVideoPreviewLayer(session: session)
                preview.frame = self.view.layer.bounds
                preview.videoGravity = .resizeAspectFill
                self.view.layer.insertSublayer(preview, at: 0)
                self.previewLayer = preview
            }
            
            session.startRunning()
        }
    }
    
    private func showCameraMessage(_ message: String) {
        let label = UILabel()
        label.text = message
        label.numberOfLines = 0
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }
    
    private func stopSession() {
        guard let session = captureSession else {
            return
        }
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }
    
    private func setupCancelButton() {
        let button = UIButton(type: .system)
        button.setTitle("Zrušiť", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.frame = CGRect(x: 20, y: 50, width: 80, height: 44)
        button.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(button)
    }
    
    @objc private func cancelTapped() {
        delegate?.qrScannerDidCancel()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }
    
    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  let stringValue = readableObject.stringValue else { return }
            Task { @MainActor [weak self] in
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                self?.delegate?.qrScannerDidScan(code: stringValue)
                self?.stopSession()
            }
        }
    }
}
