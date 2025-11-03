import SwiftUI
import AVFoundation

struct InventoryScannerView: UIViewControllerRepresentable {
    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var onCode: (String) -> Void

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                             didOutput metadataObjects: [AVMetadataObject],
                             from connection: AVCaptureConnection) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let code = object.stringValue else { return }
            onCode(code)
            onCode = { _ in }
        }
    }

    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onCode = onCode
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController {
    var onCode: ((String) -> Void)?
    var coordinator: InventoryScannerView.Coordinator?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        session.startRunning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(coordinator, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.code128, .qr, .ean13, .ean8, .pdf417]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer

        let guide = UILabel()
        guide.text = "Align barcode in frame"
        guide.textColor = .white
        guide.font = .preferredFont(forTextStyle: .headline)
        guide.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(guide)
        NSLayoutConstraint.activate([
            guide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guide.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
    }
}
