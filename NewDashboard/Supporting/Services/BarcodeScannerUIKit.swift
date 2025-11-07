//
//  BarcodeScannerUIKit.swift
//  NewDashboard
//
//  Hardened for SwiftUI .sheet, Simulator/Catalyst gating,
//  safer metadata type assignment, and extra diagnostics.
//

import SwiftUI
import AVFoundation
import UIKit

struct BarcodeScannerUIKit: UIViewControllerRepresentable {
    typealias UIViewControllerType = ScannerVC
    var onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onFound = { value in
            DispatchQueue.main.async { onCode(value) }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: ScannerVC, coordinator: ()) {
        uiViewController.cleanShutdown()
    }
}

final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var onFound: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let output = AVCaptureMetadataOutput()
    private var preview: AVCaptureVideoPreviewLayer?

    private let callbackQueue = DispatchQueue(label: "scanner.metadata.queue")
    private var isConfigured = false
    private var didReportFatal = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        requestAndConfigure()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
        preview?.session = nil
    }

    func cleanShutdown() {
        if session.isRunning { session.stopRunning() }
        preview?.session = nil
    }

    // MARK: - Permissions & Configuration

    private func requestAndConfigure() {
        #if targetEnvironment(simulator)
        showError("Camera not available in Simulator.")
        return
        #elseif targetEnvironment(macCatalyst)
        showError("Camera scanning isn’t supported under Mac Catalyst in this build.")
        return
        #else
        // Ensure Info.plist has the camera usage description; missing key will crash in production/TestFlight
        if Bundle.main.object(forInfoDictionaryKey: "NSCameraUsageDescription") == nil {
            showError("This build is missing the required NSCameraUsageDescription in Info.plist.")
            return
        }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showError("No camera available on this device.")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            Task { @MainActor in configureSessionIfNeeded() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    granted ? self.configureSessionIfNeeded()
                            : self.showError("Camera access denied. Enable it in Settings.")
                }
            }
        case .denied, .restricted:
            showError("Camera access denied. Enable it in Settings.")
        @unknown default:
            showError("Unknown camera permission state.")
        }
        #endif
    }

    @MainActor
    private func configureSessionIfNeeded() {
        guard !isConfigured else {
            if !session.isRunning { session.startRunning() }
            return
        }

        // Pick a real back camera via discovery session for reliability
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualWideCamera, .builtInTripleCamera],
            mediaType: .video,
            position: .back
        )
        guard let device = discovery.devices.first ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            showError("No usable back camera found.")
            return
        }

        session.beginConfiguration()

        // Inputs
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                showError("Unable to add camera input.")
                session.commitConfiguration()
                return
            }
            session.addInput(input)
        } catch {
            showError("Failed to open camera input: \(error.localizedDescription)")
            session.commitConfiguration()
            return
        }

        // Outputs
        guard session.canAddOutput(output) else {
            showError("Scanner output not available.")
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: callbackQueue)

        // Finish configuring the session before starting it
        session.commitConfiguration()

        // Preview
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        preview = layer

        isConfigured = true
        session.startRunning()

        // Assign metadata types AFTER session starts to avoid device races.
        // Tiny async hop gives the output a beat to populate supported types on some iPads.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            let requested: [AVMetadataObject.ObjectType] = [.qr, .ean8, .ean13, .code128, .pdf417]
            let supported = Set(self.output.availableMetadataObjectTypes)
            let filtered = requested.filter { supported.contains($0) }

            if filtered.isEmpty {
                self.showError("No supported barcode types on this device.")
                return
            }
            self.output.metadataObjectTypes = filtered
            // Quick diagnostic print for your console
            print("Scanner active. Supported types:", supported)
        }
    }

    // MARK: - Delegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = first.stringValue else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            self.onFound?(value)
        }
    }

    // MARK: - UI Errors

    private func showError(_ message: String) {
        if didReportFatal { return }
        didReportFatal = true

        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .body)

        let plate = UIView()
        plate.translatesAutoresizingMaskIntoConstraints = false
        plate.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        plate.layer.cornerRadius = 12

        view.addSubview(plate)
        view.addSubview(label)

        NSLayoutConstraint.activate([
            plate.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            plate.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            plate.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            plate.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            label.leadingAnchor.constraint(equalTo: plate.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: plate.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: plate.topAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: plate.bottomAnchor, constant: -16),
        ])

        // Also log to the console for fast triage
        print("Scanner fatal:", message)
    }
}

