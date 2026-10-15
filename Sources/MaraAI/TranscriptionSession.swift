import AVFoundation
import Speech

/// Connects system audio capture to SpeechAnalyzer (Apple's on-device transcription).
final class TranscriptionSession {
    private let capture = SystemAudioCapture()
    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    static func supportedLocales() async -> [Locale] {
        await SpeechTranscriber.supportedLocales
    }

    /// The download that installs the speech model for `locale`, or nil when it is already on the
    /// Mac. The introduction uses it to fetch the model before the first meeting.
    static func modelDownload(for locale: Locale) async throws -> AssetInstallationRequest? {
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw AppError.message(localized("O Apple Speech não transcreve o idioma \(locale.identifier)."))
        }
        let transcriber = SpeechTranscriber(
            locale: supported,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults, .fastResults],
            attributeOptions: []
        )
        return try await AssetInventory.assetInstallationRequest(supporting: [transcriber])
    }

    func start(
        locale: Locale,
        vocabulary: [String],
        gate: ActivityGate,
        onAudio: ((AVAudioPCMBuffer) -> Void)? = nil,
        onStatus: @escaping @MainActor (String) -> Void,
        onResult: @escaping @MainActor (_ text: String, _ isFinal: Bool) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) async throws {
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw AppError.message(localized("O Apple Speech não transcreve o idioma \(locale.identifier)."))
        }

        let transcriber = SpeechTranscriber(
            locale: supported,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults, .fastResults],
            attributeOptions: []
        )

        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            await onStatus(localized("Baixando o modelo de transcrição deste idioma…"))
            try await request.downloadAndInstall()
        }

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw AppError.message(localized("O Apple Speech não informou um formato de áudio compatível."))
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        // Glossary terms help recognition get proper nouns and product names right.
        if !vocabulary.isEmpty {
            let context = AnalysisContext()
            context.contextualStrings[.general] = vocabulary
            try? await analyzer.setContext(context)
        }
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.analyzer = analyzer
        self.input = continuation

        resultsTask = Task {
            do {
                for try await result in transcriber.results {
                    await onResult(String(result.text.characters), result.isFinal)
                }
            } catch {
                await onError(error)
            }
        }

        try await analyzer.start(inputSequence: stream)

        // The converter is only used on the capture queue.
        let converter = BufferConverter()
        try await capture.start(
            onBuffer: { buffer in
                guard let converted = converter.convert(buffer, to: format) else { return }
                onAudio?(converted)
                // While on standby, audio is still metered but isn't sent to transcription.
                for ready in gate.pass(converted) {
                    continuation.yield(AnalyzerInput(buffer: ready))
                }
            },
            onStop: { [weak self] error in
                Task { @MainActor in await self?.recover(from: error, onError: onError) }
            }
        )
    }

    private var restarts: [Date] = []

    /// macOS sometimes interrupts capture (for example, when switching tabs or Spaces). Instead of
    /// ending the session, reopen the capture; give up only if this happens 5 times within a minute.
    @MainActor
    private func recover(from error: Error, onError: @escaping @MainActor (Error) -> Void) async {
        restarts = restarts.filter { $0 > Date().addingTimeInterval(-60) }
        SessionLog.write("CAPTURA interrompida: \(error.localizedDescription)")
        guard restarts.count < 5 else {
            onError(error)
            return
        }
        restarts.append(Date())
        try? await Task.sleep(for: .milliseconds(500))
        do {
            try await capture.restart()
            SessionLog.write("CAPTURA retomada")
        } catch {
            onError(error)
        }
    }

    func stop() async {
        await capture.stop()
        input?.finish()
        input = nil
        // Finalize whatever was pending; the results loop ends on its own after that.
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        analyzer = nil
    }
}

/// Converts the capture's 48 kHz buffers to the format SpeechAnalyzer asks for.
final class BufferConverter {
    private var converter: AVAudioConverter?

    func convert(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format == format { return buffer }

        if converter == nil || converter?.inputFormat != buffer.format || converter?.outputFormat != format {
            converter = AVAudioConverter(from: buffer.format, to: format)
            converter?.primeMethod = .none
        }
        guard let converter else { return nil }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 1
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }

        var provided = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if provided {
                inputStatus.pointee = .noDataNow
                return nil
            }
            provided = true
            inputStatus.pointee = .haveData
            return buffer
        }
        return status == .error || output.frameLength == 0 ? nil : output
    }
}

/// Decides whether audio goes on to transcription. Tracks when sound was last heard and, while on
/// standby, keeps the last second and a half so speech isn't clipped when sound comes back.
final class ActivityGate {
    private let lock = NSLock()
    private var paused = false
    private var lastSound = Date()
    private var held: [AVAudioPCMBuffer] = []
    private var heldFrames = 0
    /// Volume (RMS, 0 to 1) above which a chunk counts as sound.
    private static let threshold = 0.006

    var secondsSinceSound: Double {
        lock.lock()
        defer { lock.unlock() }
        return Date().timeIntervalSince(lastSound)
    }

    func setPaused(_ value: Bool) {
        lock.lock()
        paused = value
        lock.unlock()
    }

    /// Called on the capture queue. Returns what should be transcribed now.
    func pass(_ buffer: AVAudioPCMBuffer) -> [AVAudioPCMBuffer] {
        let loud = Self.level(of: buffer) > Self.threshold
        lock.lock()
        defer { lock.unlock() }
        if loud { lastSound = Date() }
        guard !paused else {
            held.append(buffer)
            heldFrames += Int(buffer.frameLength)
            let limit = Int(buffer.format.sampleRate * 1.5)
            while heldFrames > limit, held.count > 1 {
                heldFrames -= Int(held.removeFirst().frameLength)
            }
            return []
        }
        let ready = held + [buffer]
        held = []
        heldFrames = 0
        return ready
    }

    private static func level(of buffer: AVAudioPCMBuffer) -> Double {
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var sum = 0.0
        if let channel = buffer.int16ChannelData?[0] {
            for index in 0..<frames {
                let sample = Double(channel[index]) / 32_768
                sum += sample * sample
            }
        } else if let channel = buffer.floatChannelData?[0] {
            for index in 0..<frames { sum += Double(channel[index]) * Double(channel[index]) }
        }
        return (sum / Double(frames)).squareRoot()
    }
}
