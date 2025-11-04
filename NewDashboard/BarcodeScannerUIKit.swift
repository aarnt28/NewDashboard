//
//  BarcodeScannerUIKit.swift
//  NewDashboard
//
//  Regenerated with safer lifecycle + permissions + simulator gating.
//  Drop this in place of your existing file.
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - SwiftUI wrapper

struct BarcodeScannerUIKit: UIViewControllerRepresentable {
    typealias UIViewControllerType = ScannerVC

    /// Called on the main thread with the scanned string value.
    var onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onFound = { value in
            // Ensure UI updates happen on main
            DispatchQueue.main.async {
                onCode(value)
            }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {
        // no-op
    }

    static func dismantleUIViewController(_ uiViewController: ScannerVC, coordinator: ()) {
        uiViewController.cleanShutdown()
    }
}

// MARK: - UIKit scanner

final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    // Public callback
    var onFound: ((String) -> Void)?

    // Capture pipeline
    private let session = AVCaptureSession()
    private let output = AVCaptureMetadataOutput()
    private var preview: AVCaptureVideoPreviewLayer?

    // Internal
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
        // Stop cleanly when sheet dismisses or view hierarchy changes
        if session.isRunning { session.stopRunning() }
        preview?.session = nil
    }

    /// Explicit shutdown for Representable dismantle
    func cleanShutdown() {
        if session.isRunning { session.stopRunning() }
        preview?.session = nil
    }

    // MARK: - Permissions & Configuration

    private func requestAndConfigure() {
        #if targetEnvironment(simulator)
        showError("""
        Camera not available in Simulator.
        Run on a physical device to scan barcodes.
        """)
        return
        #endif

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showError("No camera available on this device.")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            Task { @MainActor in configureSessionIfNeeded() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                DispatchQueue.main.async {
                    if granted {
                        self.configureSessionIfNeeded()
                    } else {
                        self.showError("Camera access denied.\nEnable in Settings > Privacy > Camera.")
                    }
                }
            }
        case .denied, .restricted:
            showError("Camera access denied.\nEnable in Settings > Privacy > Camera.")
        @unknown default:
            showError("Camera permission status unknown.")
        }
    }

    @MainActor
    private func configureSessionIfNeeded() {
        guard !isConfigured else {
            // If already configured (e.g., returning to view), just start
            if !session.isRunning { session.startRunning() }
            return
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Input
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            showError("Unable to open the back camera.")
            return
        }
        session.addInput(input)

        // Output
        guard session.canAddOutput(output) else {
            showError("Scanner output not available.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: callbackQueue)

        // Restrict to supported types only
        let requested: [AVMetadataObject.ObjectType] = [.qr, .ean8, .ean13, .code128]
        let supported = Set(output.availableMetadataObjectTypes)
        let filtered = requested.filter { supported.contains($0) }

        if filtered.isEmpty {
            showError("No supported barcode types on this device.")
            return
        }
        output.metadataObjectTypes = filtered

        // Preview
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        preview = layer

        isConfigured = true
        session.startRunning()
    }

    // MARK: - Delegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let first = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = first.stringValue else { return }

        // Stop once we have a value and report back on main
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            self.onFound?(value)
        }
    }

    // MARK: - UI Errors

    private func showError(_ message: String) {
        // Avoid layering multiple labels if called more than once
        if didReportFatal { return }
        didReportFatal = true

        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .body)

        // Dimmed background to make text readable
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
    }
}
