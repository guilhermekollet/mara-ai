import AVFoundation
import ScreenCaptureKit

/// Captures the audio coming out of the Mac (Zoom, Meet, Teams, browser) via ScreenCaptureKit and,
/// when turned on, the microphone, which arrives on the same stream as a separate output.
final class SystemAudioCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private var stream: SCStream?
    private let queue = DispatchQueue(label: "mara-ai.audio-capture")
    private let microphoneQueue = DispatchQueue(label: "mara-ai.microphone-capture")
    private var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    private var onMicrophone: ((AVAudioPCMBuffer) -> Void)?
    private var onStop: ((Error) -> Void)?
    private var onMicrophoneLost: (() -> Void)?
    /// Kept so a restarted stream captures the microphone too, if it was on.
    private var capturesMicrophone = false

    func start(
        microphone: Bool,
        onBuffer: @escaping (AVAudioPCMBuffer) -> Void,
        onMicrophone: @escaping (AVAudioPCMBuffer) -> Void,
        onMicrophoneLost: @escaping () -> Void,
        onStop: @escaping (Error) -> Void
    ) async throws {
        self.onBuffer = onBuffer
        self.onMicrophone = onMicrophone
        self.onMicrophoneLost = onMicrophoneLost
        self.onStop = onStop
        capturesMicrophone = microphone
        try await startStreamKeepingSystemAudio()
    }

    /// Turns the microphone on or off without interrupting the Mac's audio.
    func setMicrophone(_ on: Bool) async throws {
        guard on != capturesMicrophone else { return }
        capturesMicrophone = on
        guard let stream else { return }
        do {
            try await stream.updateConfiguration(configuration())
        } catch {
            // Not every change applies to a running stream; a new one picks the setting up.
            try await restart()
        }
    }

    /// Opens a new stream with the same handlers. Used when the system interrupts capture
    /// (switching Spaces, full-screen tabs, displays…), so the session carries on without the user noticing.
    func restart() async throws {
        let old = stream
        stream = nil
        try? await old?.stopCapture()
        try await startStreamKeepingSystemAudio()
    }

    /// A stream that won't start with the microphone (permission revoked, device gone) starts
    /// without it, so the meeting's captions carry on; `onMicrophoneLost` reports it.
    private func startStreamKeepingSystemAudio() async throws {
        do {
            try await startStream()
        } catch {
            guard capturesMicrophone else { throw error }
            capturesMicrophone = false
            try await startStream()
            onMicrophoneLost?()
        }
    }

    private func startStream() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else {
            throw AppError.message(localized("Nenhuma tela encontrada para capturar o áudio."))
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let stream = SCStream(filter: filter, configuration: configuration(), delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: microphoneQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    private func configuration() -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 1
        // Video is mandatory on the stream, so keep it as small as possible.
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        // The system default microphone, in its own format (the converter adapts it).
        config.captureMicrophone = capturesMicrophone
        return config
    }

    func stop() async {
        try? await stream?.stopCapture()
        stream = nil
        onBuffer = nil
        onMicrophone = nil
        onMicrophoneLost = nil
        onStop = nil
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid, let buffer = Self.pcmBuffer(from: sampleBuffer) else { return }
        switch type {
        case .audio: onBuffer?(buffer)
        case .microphone: onMicrophone?(buffer)
        default: break
        }
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
