import AVFoundation
import Speech

/// Connects audio capture to SpeechAnalyzer (Apple's on-device transcription): one recognizer for
/// the Mac's audio and, while the microphone is on, another for it.
final class TranscriptionSession {
    private let capture = SystemAudioCapture()
    private var system: Recognizer?
    private let microphone = MicrophoneInput()
    private var microphoneRecognizer: Recognizer?
    private var locale = Locale.current
    private var vocabulary: [String] = []
    private var onResult: (@MainActor (_ text: String, _ isFinal: Bool, _ speaker: Speaker, _ range: CMTimeRange) -> Void)?
    private var onError: (@MainActor (Error) -> Void)?

    /// Whether what is said into the microphone is being transcribed right now.
    var microphoneActive: Bool { microphoneRecognizer != nil }

    static func supportedLocales() async -> [Locale] {
        await SpeechTranscriber.supportedLocales
    }

    /// The download that installs the speech model for `locale`, or nil when it is already on the
    /// Mac. The introduction uses it to fetch the model before the first meeting.
    static func modelDownload(for locale: Locale) async throws -> AssetInstallationRequest? {
        let transcriber = try await Recognizer.transcriber(for: locale, partials: true)
        return try await AssetInventory.assetInstallationRequest(supporting: [transcriber])
    }

    func start(
        locale: Locale,
        vocabulary: [String],
        gate: ActivityGate,
        microphoneGate: ActivityGate,
        withMicrophone: Bool,
        sentenceAudio: SentenceAudio? = nil,
        onAudio: ((AVAudioPCMBuffer) -> Void)? = nil,
        onStatus: @escaping @MainActor (String) -> Void,
        onResult: @escaping @MainActor (_ text: String, _ isFinal: Bool, _ speaker: Speaker, _ range: CMTimeRange) -> Void,
        onMicrophoneLost: @escaping @MainActor () -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) async throws {
        self.locale = locale
        self.vocabulary = vocabulary
        self.onResult = onResult
        self.onError = onError
        microphone.gate = microphoneGate

        let transcriber = try await Recognizer.transcriber(for: locale, partials: true)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            await onStatus(localized("Baixando o modelo de transcrição deste idioma…"))
            try await request.downloadAndInstall()
        }
        let system = try await Recognizer.start(
            transcriber, vocabulary: vocabulary,
            onResult: { text, isFinal, range in onResult(text, isFinal, .others, range) },
            onError: onError
        )
        self.system = system
        // A microphone that fails doesn't take the meeting's captions down with it.
        var withMicrophone = withMicrophone
        if withMicrophone {
            do {
                try await startMicrophoneRecognizer()
            } catch {
                withMicrophone = false
                await onStatus(localized("Não foi possível usar o microfone: \(error.localizedDescription)"))
            }
        }

        // The converter is only used on the capture queue.
        let converter = BufferConverter()
        let format = system.format
        let input = system.input
        try await capture.start(
            microphone: withMicrophone,
            onBuffer: { buffer in
                guard let converted = converter.convert(buffer, to: format) else { return }
                onAudio?(converted)
                // While on standby, audio is still metered but isn't sent to transcription.
                for ready in gate.pass(converted) {
                    // Kept in step with what the recognizer hears, so a sentence's time range
                    // finds its audio.
                    sentenceAudio?.append(ready)
                    input.yield(AnalyzerInput(buffer: ready))
                }
            },
            onMicrophone: { [microphone] buffer in microphone.push(buffer) },
            onMicrophoneLost: { [weak self] in
                Task { @MainActor in
                    await self?.stopMicrophoneRecognizer()
                    onMicrophoneLost()
                }
            },
            onStop: { [weak self] error in
                Task { @MainActor in await self?.recover(from: error, onError: onError) }
            }
        )
    }

    /// Turns the microphone's transcription on or off in the middle of a session. On the main
    /// actor, like `recover`, so the two never change the stream at the same time.
    @MainActor
    func setMicrophone(_ on: Bool) async throws {
        if on {
            try await startMicrophoneRecognizer()
            try await capture.setMicrophone(true)
        } else {
            try await capture.setMicrophone(false)
            await stopMicrophoneRecognizer()
        }
    }

    /// Only finished sentences: the person speaking knows what they said, so the captions don't
    /// need to follow them word by word.
    private func startMicrophoneRecognizer() async throws {
        guard microphoneRecognizer == nil, let onResult, let onError else { return }
        let transcriber = try await Recognizer.transcriber(for: locale, partials: false)
        let recognizer = try await Recognizer.start(
            transcriber, vocabulary: vocabulary,
            onResult: { text, isFinal, range in onResult(text, isFinal, .me, range) },
            onError: onError
        )
        microphoneRecognizer = recognizer
        microphone.connect(recognizer)
    }

    private func stopMicrophoneRecognizer() async {
        microphone.disconnect()
        await microphoneRecognizer?.finish()
        microphoneRecognizer = nil
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
        await stopMicrophoneRecognizer()
        await system?.finish()
        system = nil
    }
}

/// One SpeechAnalyzer with its transcriber, fed buffers already in the format it asked for.
final class Recognizer {
    let format: AVAudioFormat
    let input: AsyncStream<AnalyzerInput>.Continuation
    private let analyzer: SpeechAnalyzer
    private let results: Task<Void, Never>

    private init(format: AVAudioFormat, input: AsyncStream<AnalyzerInput>.Continuation, analyzer: SpeechAnalyzer, results: Task<Void, Never>) {
        self.format = format
        self.input = input
        self.analyzer = analyzer
        self.results = results
    }

    /// `partials` adds the provisional results that let the captions follow a sentence as it is said.
    static func transcriber(for locale: Locale, partials: Bool) async throws -> SpeechTranscriber {
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw AppError.message(localized("O Apple Speech não transcreve o idioma \(locale.identifier)."))
        }
        return SpeechTranscriber(
            locale: supported,
            transcriptionOptions: [],
            reportingOptions: partials ? [.volatileResults, .fastResults] : [],
            attributeOptions: []
        )
    }

    static func start(
        _ transcriber: SpeechTranscriber,
        vocabulary: [String],
        onResult: @escaping @MainActor (_ text: String, _ isFinal: Bool, _ range: CMTimeRange) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) async throws -> Recognizer {
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
        let results = Task {
            do {
                for try await result in transcriber.results {
                    await onResult(String(result.text.characters), result.isFinal, result.range)
                }
            } catch {
                await onError(error)
            }
        }
        do {
            try await analyzer.start(inputSequence: stream)
        } catch {
            continuation.finish()
            results.cancel()
            throw error
        }
        return Recognizer(format: format, input: continuation, analyzer: analyzer, results: results)
    }

    /// Finalizes whatever was pending; the results loop ends on its own after that.
    func finish() async {
        input.finish()
        try? await analyzer.finalizeAndFinishThroughEndOfInput()
    }
}

/// Where the microphone's audio goes. Connected and disconnected on the main actor while the capture
/// queue pushes buffers, so the recognizer it feeds is guarded by a lock.
final class MicrophoneInput: @unchecked Sendable {
    private let lock = NSLock()
    private var recognizer: Recognizer?
    private let converter = BufferConverter()
    var gate: ActivityGate?

    func connect(_ recognizer: Recognizer) {
        lock.lock()
        self.recognizer = recognizer
        lock.unlock()
    }

    func disconnect() {
        lock.lock()
        recognizer = nil
        lock.unlock()
    }

    func push(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard let recognizer, let converted = converter.convert(buffer, to: recognizer.format) else { return }
        for ready in gate?.pass(converted) ?? [converted] {
            recognizer.input.yield(AnalyzerInput(buffer: ready))
        }
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
            // The microphone can have several channels; speech recognition wants one.
            converter?.downmix = true
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
    private var muted = false
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

    /// Muted, audio is thrown away instead of held: the microphone while Mara reads aloud on
    /// speakers, so her voice doesn't become yours.
    func setMuted(_ value: Bool) {
        lock.lock()
        muted = value
        held = []
        heldFrames = 0
        lock.unlock()
    }

    /// Called on the capture queue. Returns what should be transcribed now.
    func pass(_ buffer: AVAudioPCMBuffer) -> [AVAudioPCMBuffer] {
        let loud = Self.level(of: buffer) > Self.threshold
        lock.lock()
        defer { lock.unlock() }
        guard !muted else { return [] }
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

/// The last half minute of the meeting audio that went to transcription, counted from the start
/// of the session in the recognizer's own timeline (standby gaps don't count), so the time range
/// of a finished sentence finds exactly its audio: the voice to tell who said it.
final class SentenceAudio: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [Float] = []
    /// How many samples came before `samples[0]`.
    private var dropped = 0
    private var sampleRate = 16_000.0
    private static let keep: Double = 30

    /// Called on the capture queue with each buffer handed to the recognizer.
    func append(_ buffer: AVAudioPCMBuffer) {
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }
        var incoming = [Float](repeating: 0, count: count)
        if let channel = buffer.floatChannelData?[0] {
            for index in 0..<count { incoming[index] = channel[index] }
        } else if let channel = buffer.int16ChannelData?[0] {
            for index in 0..<count { incoming[index] = Float(channel[index]) / 32_768 }
        } else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        sampleRate = buffer.format.sampleRate
        samples += incoming
        let limit = Int(sampleRate * Self.keep)
        if samples.count > limit {
            let excess = samples.count - limit
            samples.removeFirst(excess)
            dropped += excess
        }
    }

    /// The audio between `start` and `end` seconds, as far as it is still kept, and its sample rate.
    func clip(from start: Double, to end: Double) -> (samples: [Float], sampleRate: Double) {
        lock.lock()
        defer { lock.unlock() }
        let first = max(0, Int(start * sampleRate) - dropped)
        let last = min(samples.count, Int(end * sampleRate) - dropped)
        guard first < last else { return ([], sampleRate) }
        return (Array(samples[first..<last]), sampleRate)
    }
}
