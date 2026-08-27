//
//  QRCodeScannerView.swift
//  gameshelf
//
//  Created by Erik Uhlin on 2026-08-27.
//

import SwiftUI
import AVFoundation

struct QRCodeScannerView: UIViewControllerRepresentable {
    var onScanned: (String) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned, onCancel: onCancel)
    }

    class Coordinator: NSObject, ScannerViewControllerDelegate {
        let onScanned: (String) -> Void
        let onCancel: () -> Void

        init(onScanned: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.onScanned = onScanned
            self.onCancel = onCancel
        }

        func didScanCode(_ code: String) {
            onScanned(code)
        }

        func didCancel() {
            onCancel()
        }
    }
}

protocol ScannerViewControllerDelegate: AnyObject {
    func didScanCode(_ code: String)
    func didCancel()
}

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerViewControllerDelegate?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isScanning = true

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupOverlay()
    }

    private func setupCamera() {
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            showNoCameraAlert()
            return
        }

        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            showNoCameraAlert()
            return
        }

        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
        } else {
            showNoCameraAlert()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)

            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            showNoCameraAlert()
            return
        }

        self.captureSession = session

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func setupOverlay() {
        // Reticle / Box
        let boxSize: CGFloat = 250
        let boxView = UIView()
        boxView.translatesAutoresizingMaskIntoConstraints = false
        boxView.layer.borderColor = UIColor.systemRed.cgColor
        boxView.layer.borderWidth = 3
        boxView.layer.cornerRadius = 24
        boxView.backgroundColor = UIColor.clear
        view.addSubview(boxView)

        // Close Button
        let closeBtn = UIButton(type: .system)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeBtn.tintColor = .white
        closeBtn.contentVerticalAlignment = .fill
        closeBtn.contentHorizontalAlignment = .fill
        closeBtn.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        view.addSubview(closeBtn)

        // Instruction Label
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Rikta kameran mot QR-koden på webben"
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 2
        view.addSubview(label)

        NSLayoutConstraint.activate([
            boxView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            boxView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30),
            boxView.widthAnchor.constraint(equalToConstant: boxSize),
            boxView.heightAnchor.constraint(equalToConstant: boxSize),

            closeBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeBtn.widthAnchor.constraint(equalToConstant: 36),
            closeBtn.heightAnchor.constraint(equalToConstant: 36),

            label.topAnchor.constraint(equalTo: boxView.bottomAnchor, constant: 28),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    @objc private func handleClose() {
        delegate?.didCancel()
    }

    private func showNoCameraAlert() {
        let label = UILabel()
        label.text = "Kameran är inte tillgänglig i simulatorn."
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.frame = view.bounds
        view.addSubview(label)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard isScanning,
              let metadataObject = metadataObjects.first,
              let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readableObject.stringValue else { return }

        isScanning = false
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        captureSession?.stopRunning()
        delegate?.didScanCode(stringValue)
    }
}
