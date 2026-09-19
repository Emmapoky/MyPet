import AVFoundation
import SwiftUI
import UIKit

/// Live camera feed for the behaviour check.
///
/// The camera only runs while this screen is open and only because the carer
/// opened it. There is no background or continuous capture (FR-N02).
final class CameraController: ObservableObject {

    enum Status { case idle, running, unavailable, denied }

    @Published private(set) var status: Status = .idle
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "mypet.camera")
    private var isConfigured = false

    /// False in the Simulator, which has no camera.
    static var hasCamera: Bool { AVCaptureDevice.default(for: .video) != nil }

    func start() {
        guard Self.hasCamera else { status = .unavailable; return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.run() } else { self?.status = .denied }
                }
            }
        default:
            status = .denied
        }
    }

    func stop() {
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func run() {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                   let input = try? AVCaptureDeviceInput(device: device),
                   self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                self.session.commitConfiguration()
                self.isConfigured = true
            }
            self.session.startRunning()
            DispatchQueue.main.async { self.status = .running }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
