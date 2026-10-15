import AVFoundation

/// Which sentences get read, in order. Speech is slower than captions, so the queue stays short:
/// the sentence being read is never cut, at most two wait behind it, and a sentence that waited
/// too long is skipped. Falling behind, the voice speeds up a little instead.
struct ReadoutQueue {
    struct Item: Equatable {
        let id: UUID
        let finalizedAt: Date
        let gender: VoiceGender?
    }

    static let maxWaiting = 2
    /// A sentence older than this, by the time its turn comes, is no longer worth hearing.
    static let staleAfter: TimeInterval = 10

    private(set) var waiting: [Item] = []

    mutating func push(_ item: Item) {
        waiting.append(item)
        if waiting.count > Self.maxWaiting { waiting.removeFirst(waiting.count - Self.maxWaiting) }
    }

    /// The next sentence to read, skipping the stale ones.
    mutating func next(now: Date = Date()) -> Item? {
        waiting.removeAll { now.timeIntervalSince($0.finalizedAt) > Self.staleAfter }
        return waiting.isEmpty ? nil : waiting.removeFirst()
    }

    mutating func clear() { waiting = [] }

    /// How much faster than the chosen speed to read, given how many sentences still wait.
    static func boost(waiting: Int) -> Double {
        1 + 0.1 * Double(min(waiting, maxWaiting))
    }
}

/// Reads finished captions aloud with an on-device neural voice (`Synthesizer`), through Mara's own
/// audio engine. ScreenCaptureKit leaves Mara's own sound out of the capture
/// (`excludesCurrentProcessAudio`, measured: nothing of it reaches the meeting audio), so the voice
/// never comes back as captions. The microphone is another matter: on speakers it hears Mara, so
/// `onSpeakingChanged` lets the session pause it.
@MainActor
final class CaptionReader {
    /// What a sentence says right now, and whether that's GPT's final version.
    var text: (UUID) -> (text: String, refined: Bool)? = { _ in nil }
    /// Whether a GPT version of each sentence is on its way, worth waiting a moment for.
    var expectsRefinement = false
    var onSpeakingChanged: (Bool) -> Void = { _ in }
    /// Picks the voice for a sentence: the language's voice for that gender.
    var voiceFor: (VoiceGender?) -> String = { _ in "F1" }
    var language = "pt"
    var speed = 1.0
    var volume = 0.9 {
        didSet { player.volume = Float(volume) }
    }

    /// The last sentences read, with when they ended, for the microphone's echo filter.
    private(set) var recentlySpoken: [(text: String, endedAt: Date)] = []

    private var queue = ReadoutQueue()
    private var synthesizer: Synthesizer?
    private var loading: Task<Synthesizer?, Never>?
    private var worker: Task<Void, Never>?
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var connectedRate: Double?
    private var speaking = false
    private var quietAgain: Task<Void, Never>?
    private var idleStop: Task<Void, Never>?
    /// The previous sentence's voice, kept when the pitch doesn't tell.
    private var lastGender: VoiceGender = .female

    /// How long to wait for GPT's version of a sentence, counted from when it was finalized.
    static let refinementWait: TimeInterval = 1.5
    /// The microphone stays paused this long after Mara stops: the sound's way out of the
    /// speakers and back into the microphone, plus the room's echo.
    static let microphoneTail: Duration = .milliseconds(400)

    init() {
        engine.attach(player)
        player.volume = Float(volume)
    }

    var isLoaded: Bool { synthesizer != nil }

    /// Loads `engine`'s model ahead of the first sentence. Does nothing if it is already loaded.
    @discardableResult
    func load(_ engine: VoiceEngine) async -> Bool {
        if synthesizer?.engine == engine { return true }
        if let loading, let loaded = await loading.value, loaded.engine == engine { return true }
        let task = Task<Synthesizer?, Never> {
            do {
                return try await Synthesizer.load(engine)
            } catch {
                SessionLog.write("VOZ não carregou: \(error.localizedDescription)")
                return nil
            }
        }
        loading = task
        let loaded = await task.value
        loading = nil
        synthesizer = loaded
        return loaded != nil
    }

    /// Frees the model's memory (several hundred megabytes) between meetings.
    func unload() {
        stop()
        synthesizer = nil
    }

    func enqueue(_ item: ReadoutQueue.Item) {
        queue.push(item)
        guard worker == nil else { return }
        worker = Task { [weak self] in
            await self?.drain()
            self?.worker = nil
        }
    }

    /// Silences Mara at once and forgets the waiting sentences.
    func stop() {
        queue.clear()
        worker?.cancel()
        worker = nil
        player.stop()
        setSpeaking(false, immediately: true)
    }

    /// Reads one sentence right away, outside any meeting: the Settings' "Ouvir" button.
    func preview(_ text: String, voice: String, language: String, engine voiceEngine: VoiceEngine) async {
        guard await load(voiceEngine), let synthesizer else { return }
        guard let samples = try? await synthesizer.synthesize(text, voice: voice, language: language, speed: speed) else { return }
        player.stop()
        await play(samples, sampleRate: synthesizer.sampleRate)
    }

    private func drain() async {
        while !Task.isCancelled, let item = queue.next() {
            guard let synthesizer else { return }
            let gender = item.gender ?? lastGender
            lastGender = gender
            guard let text = await resolvedText(item), !text.isEmpty else { continue }
            let pace = speed * ReadoutQueue.boost(waiting: queue.waiting.count)
            let started = Date()
            guard let samples = try? await synthesizer.synthesize(text, voice: voiceFor(gender), language: language, speed: pace),
                  !Task.isCancelled else { continue }
            SessionLog.write("VOZ \(gender.rawValue) \(SessionLog.ms(since: started)) espera=\(queue.waiting.count) \(text)")
            await play(samples, sampleRate: synthesizer.sampleRate)
            recentlySpoken.append((text, Date()))
            recentlySpoken.removeAll { Date().timeIntervalSince($0.endedAt) > 30 }
        }
    }

    /// The sentence's best text: GPT's when it arrives in time, otherwise Apple's.
    private func resolvedText(_ item: ReadoutQueue.Item) async -> String? {
        while expectsRefinement, let current = text(item.id), !current.refined,
              Date().timeIntervalSince(item.finalizedAt) < Self.refinementWait, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return text(item.id)?.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func play(_ samples: [Float], sampleRate: Double) async {
        guard !samples.isEmpty, let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
        }
        if connectedRate != sampleRate {
            engine.stop()
            engine.disconnectNodeOutput(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            connectedRate = sampleRate
        }
        idleStop?.cancel()
        if !engine.isRunning {
            do { try engine.start() } catch {
                SessionLog.write("VOZ sem saída de áudio: \(error.localizedDescription)")
                return
            }
        }
        setSpeaking(true)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { _ in
                continuation.resume()
            }
            player.play()
        }
        setSpeaking(false)
        // Stops the engine a little after the last sentence, so the Mac's audio isn't kept awake.
        idleStop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self, !self.speaking else { return }
            self.player.stop()
            self.engine.stop()
        }
    }

    private func setSpeaking(_ value: Bool, immediately: Bool = false) {
        quietAgain?.cancel()
        quietAgain = nil
        if value {
            guard !speaking else { return }
            speaking = true
            onSpeakingChanged(true)
        } else if speaking {
            guard !immediately else {
                speaking = false
                onSpeakingChanged(false)
                return
            }
            // The next sentence often starts right away: wait before letting the microphone back in.
            quietAgain = Task { [weak self] in
                try? await Task.sleep(for: Self.microphoneTail)
                guard !Task.isCancelled, let self, self.speaking else { return }
                self.speaking = false
                self.onSpeakingChanged(false)
            }
        }
    }
}

/// `MaraAI --try-voices <pt|en|es>`: the voices' path end to end, outside a meeting.
@MainActor
enum VoiceTrial {
    static func run(language: String) async {
        let engine = VoiceEngine.reading(language)
        let store = VoiceModelStore.shared
        if store.state(engine) != .ready {
            print("Downloading \(engine.rawValue) (\(engine.manifest.totalBytes / 1_000_000) MB)…")
            store.download(engine)
            var last = -1
            while true {
                switch store.state(engine) {
                case .downloading(let fraction):
                    let percent = Int(fraction * 100)
                    if percent / 10 != last / 10 { print("  \(percent)%") }
                    last = percent
                case .ready:
                    print("  downloaded and checked")
                case .failed(let message):
                    print("  failed: \(message)")
                    return
                case .missing:
                    print("  cancelled")
                    return
                }
                if store.state(engine) == .ready { break }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        let reader = CaptionReader()
        var started = Date()
        guard await reader.load(engine) else {
            print("could not load \(engine.rawValue)")
            return
        }
        print("loaded and warmed up in \(SessionLog.ms(since: started))")
        for gender in VoiceGender.allCases {
            let voice = ReadoutCatalog.voice(for: language, gender: gender, preferred: nil)
            started = Date()
            await reader.preview(ReadoutCatalog.sample(for: language), voice: voice.id, language: language, engine: engine)
            print("\(gender.rawValue) \(voice.id): synthesized and played in \(SessionLog.ms(since: started))")
        }
    }
}
