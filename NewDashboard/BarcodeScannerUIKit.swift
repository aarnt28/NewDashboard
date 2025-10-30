//
//  BarcodeScannerUIKit.swift
//  NewDashboard
//
//  Created by Aaron Turner on 10/30/25.
//


import SwiftUI
import AVFoundation

/// UIKit-backed scanner that never dismisses itself. The SwiftUI host decides when to close.
struct BarcodeScannerUIKit: UIViewControllerRepresentable {
    var onCode: (String) -> Void
    
    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onFound = onCode
        return vc
    }
    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}
    
    final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onFound: ((String) -> Void)?
        
        private let session = AVCaptureSession()
        private let sessionQueue = DispatchQueue(label: "scanner.session.q")
        private var preview: AVCaptureVideoPreviewLayer!
        
        private let boxLayer = CAShapeLayer()
        private let messageLabel: UILabel = {
            let l = UILabel()
            l.text = "Align the barcode in view"
            l.textColor = .white
            l.font = .systemFont(ofSize: 15, weight: .medium)
            l.translatesAutoresizingMaskIntoConstraints = false
            l.textAlignment = .center
            l.numberOfLines = 0
            l.alpha = 0.9
            return l
        }()
        
        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            
            preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            view.layer.addSublayer(preview)
            
            boxLayer.strokeColor = UIColor.systemGreen.cgColor
            boxLayer.fillColor = UIColor.clear.cgColor
            boxLayer.lineWidth = 3
            view.layer.addSublayer(boxLayer)
            
            view.addSubview(messageLabel)
            NSLayoutConstraint.activate([
                messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                messageLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
                messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16)
            ])
            
            setupSession()
        }
        
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            preview.frame = view.bounds     // orientation handled implicitly
        }
        
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            sessionQueue.async { [weak self] in
                guard let self else { return }
                if !self.session.isRunning { self.session.startRunning() }
            }
        }
        
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            sessionQueue.async { [weak self] in
                guard let self else { return }
                if self.session.isRunning { self.session.stopRunning() }
            }
        }
        
        private func setupSession() {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                configureSession()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        granted ? self?.configureSession()
                        : self?.showError("Camera access denied.\nEnable it in Settings.")
                    }
                }
            default:
                showError("Camera access denied.\nEnable it in Settings.")
            }
        }
        
        private func configureSession() {
            sessionQueue.async {
                self.session.beginConfiguration()
                defer { self.session.commitConfiguration() }
                self.session.sessionPreset = .high
                
                // Prefer back camera
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video)
                
                guard let device,
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    DispatchQueue.main.async { self.showError("Camera unavailable on this device.") }
                    return
                }
                self.session.addInput(input)
                
                let output = AVCaptureMetadataOutput()
                guard self.session.canAddOutput(output) else {
                    DispatchQueue.main.async { self.showError("Cannot add camera output.") }
                    return
                }
                self.session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: .main)
                output.metadataObjectTypes = [
                    .ean13, .ean8, .upce,
                    .code128, .code39, .code93, .itf14,
                    .qr, .pdf417, .aztec, .dataMatrix
                ]
                
                if !self.session.isRunning { self.session.startRunning() }
            }
        }
        
        private func showError(_ text: String) {
            messageLabel.text = text
            messageLabel.textColor = .systemRed
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput objs: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let raw = objs.first as? AVMetadataMachineReadableCodeObject else {
                boxLayer.path = nil
                return
            }
            
            if let transformed = preview.transformedMetadataObject(for: raw) as? AVMetadataMachineReadableCodeObject {
                let corners = transformed.corners
                let path = UIBezierPath()
                if !corners.isEmpty {
                    path.move(to: corners[0])
                    for c in corners.dropFirst() { path.addLine(to: c) }
                    path.close()
                } else {
                    path.append(UIBezierPath(rect: transformed.bounds))
                }
                boxLayer.path = path.cgPath
            } else {
                boxLayer.path = UIBezierPath(rect: raw.bounds).cgPath
            }
            
            if let value = raw.stringValue {
                // Stop once; tell SwiftUI host to dismiss
                sessionQueue.async { [weak self] in
                    self?.session.stopRunning()
                    DispatchQueue.main.async { [weak self] in
                        self?.onFound?(value)   // host will dismiss the sheet
                    }
                }
            }
        }
    }
}
