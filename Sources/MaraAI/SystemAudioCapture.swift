import AVFoundation
import ScreenCaptureKit

/// Captures the audio coming out of the Mac (Zoom, Meet, Teams, browser) via ScreenCaptureKit.
final class SystemAudioCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "mara-ai.audio-capture")
    private var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    private var onStop: ((Error) -> Void)?

    func start(
        onBuffer: @escaping (AVAudioPCMBuffer) -> Void,
        onStop: @escaping (Error) -> Void
    ) async throws {
        self.onBuffer = onBuffer
        self.onStop = onStop
        try await startStream()
    }

    /// Opens a new stream with the same handlers. Used when the system interrupts capture
    /// (switching Spaces, full-screen tabs, displays…), so the session carries on without the user noticing.
    func restart() async throws {
        let old = stream
        stream = nil
        try? await old?.stopCapture()
        try await startStream()
    }

    private func startStream() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw AppError.message("Nenhuma tela encontrada para capturar o áudio.")
        }

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 1
        // Video is mandatory on the stream, so keep it as small as possible.
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        try? await stream?.stopCapture()
        stream = nil
        onBuffer = nil
        onStop = nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid, let buffer = Self.pcmBuffer(from: sampleBuffer) else { return }
        onBuffer?(buffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        // An old stream that ends after being replaced no longer matters.
        guard stream === self.stream else { return }
        onStop?(error)
    }

    private static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let description = sampleBuffer.formatDescription else { return nil }
        let format: AVAudioFormat? = AVAudioFormat(cmAudioFormatDescription: description)
        let frames = AVAudioFrameCount(sampleBuffer.numSamples)
        guard let format, frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            return nil
        }
        buffer.frameLength = frames
        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer, at: 0, frameCount: Int32(frames), into: buffer.mutableAudioBufferList
        )
        return status == noErr ? buffer : nil
    }
}

enum AppError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}
