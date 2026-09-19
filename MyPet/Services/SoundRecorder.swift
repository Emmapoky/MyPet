import AVFoundation
import Foundation

/// Records a short sound clip for the behaviour check and reports live levels
/// for the waveform. The clip stays on the phone in a temporary file.
///
/// If microphone access is refused the check still runs (the prototype model
/// does not need the audio yet) and `isUsingMicrophone` stays false, so the UI
/// can say so honestly.
@MainActor
final class SoundRecorder: ObservableObject {

    @Published private(set) var levels: [CGFloat] = Array(repeating: 0.05, count: 32)
    @Published private(set) var isUsingMicrophone = false

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?

    func start() async {
        let granted = await AVAudioApplication.requestRecordPermission()
        if granted, let recorder = makeRecorder() {
            self.recorder = recorder
            recorder.isMeteringEnabled = true
            recorder.record()
            isUsingMicrophone = true
        } else {
            isUsingMicrophone = false
        }

        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func stop() {
        meterTimer?.invalidate()
        meterTimer = nil
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        levels = Array(repeating: 0.05, count: levels.count)
    }

    private func tick() {
        let level: CGFloat
        if let recorder {
            recorder.updateMeters()
            // dB (-160...0) mapped to 0...1, with a floor so silence still shows.
            let power = CGFloat(recorder.averagePower(forChannel: 0))
            level = max(0.05, min(1, (power + 55) / 55))
        } else {
            level = CGFloat.random(in: 0.08...0.7)
        }
        levels.removeFirst()
        levels.append(level)
    }

    private func makeRecorder() -> AVAudioRecorder? {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("behaviour-check.m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            return try AVAudioRecorder(url: url, settings: settings)
        } catch {
            return nil
        }
    }
}
