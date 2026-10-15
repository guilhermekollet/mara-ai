import AVFoundation

/// Cuts what someone is saying into pieces to read before they finish the sentence. The words of
/// a sentence in progress settle as it goes: in a real meeting, all but the last three never
/// changed again (804 of 804 updates). So once the settled part reaches a comma, or about ten
/// words, that piece is ready; when the sentence ends, whatever wasn't read yet is the last piece.
struct PieceCutter {
    /// The last words of a sentence in progress may still change.
    static let unsettledWords = 3
    /// A piece ends at punctuation once it has this many words…
    static let shortestPiece = 4
    /// …or here, when nobody pauses.
    static let longestPiece = 10

    /// How many words of the current sentence were already cut.
    private(set) var cutWords: [String] = []

    /// The next piece of the sentence in progress, if one is ready.
    mutating func partial(_ text: String) -> String? {
        let words = text.split(separator: " ").map(String.init)
        let settled = max(0, words.count - Self.unsettledWords)
        guard settled > cutWords.count else { return nil }
        let candidate = Array(words[cutWords.count..<settled])
        var end: Int?
        if candidate.count >= Self.shortestPiece {
            end = (Self.shortestPiece - 1..<candidate.count).last { index in
                candidate[index].last.map { ",;:.!?…".contains($0) } ?? false
            }.map { $0 + 1 }
        }
        if end == nil, candidate.count >= Self.longestPiece { end = Self.longestPiece }
        guard let end else { return nil }
        let piece = Array(candidate[..<end])
        cutWords += piece
        return piece.joined(separator: " ")
    }

    /// The rest of the finished sentence, after what was already cut, and a fresh start for the next.
    mutating func final(_ text: String) -> String? {
        defer { cutWords = [] }
        let words = text.split(separator: " ").map(String.init)
        let start = Self.alignedEnd(of: cutWords, in: words)
        guard start < words.count else { return nil }
        return words[start...].joined(separator: " ")
    }

    /// Where the words already cut end in the final text. The final adds punctuation and capitals
    /// and sometimes changes a word, so the words are compared loosely, around the expected place.
    static func alignedEnd(of cut: [String], in final: [String]) -> Int {
        guard !cut.isEmpty else { return 0 }
        let normalize = { (word: String) in
            word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                .filter { $0.isLetter || $0.isNumber }
        }
        let tail = cut.suffix(2).map(normalize)
        let expected = cut.count
        for offset in [0, -1, 1, -2, 2, -3, 3] {
            let end = expected + offset
            guard end >= tail.count, end <= final.count else { continue }
            if Array(final[(end - tail.count)..<end]).map(normalize) == tail { return end }
        }
        return min(expected, final.count)
    }
}

/// What gets read, in order: pieces of what the others say, each translated as soon as it's
/// stable. Speech is slower than captions, so the queue stays short: a piece being read is never
/// cut, a few wait behind it, and a piece that waited too long is skipped. Falling behind, the
/// voice speeds up a little instead.
struct ReadoutQueue {
    struct Item: Equatable {
        let id: UUID
        let createdAt: Date
        let text: String
    }

    static let maxWaiting = 4
    /// A piece older than this, by the time its turn comes, is no longer worth hearing.
    static let staleAfter: TimeInterval = 10

    private(set) var waiting: [Item] = []

    mutating func push(_ item: Item) {
        waiting.append(item)
        if waiting.count > Self.maxWaiting { waiting.removeFirst(waiting.count - Self.maxWaiting) }
    }

    /// The next piece to read, skipping the stale ones.
    mutating func next(now: Date = Date()) -> Item? {
        waiting.removeAll { now.timeIntervalSince($0.createdAt) > Self.staleAfter }
        return waiting.isEmpty ? nil : waiting.removeFirst()
    }

    mutating func clear() { waiting = [] }

    /// How much faster than the chosen speed to read, given how many pieces still wait.
    static func boost(waiting: Int) -> Double {
        1 + 0.1 * Double(min(waiting, 3))
    }
}

/// Reads the captions aloud with an on-device neural voice (`Synthesizer`), through Mara's own
/// audio engine. ScreenCaptureKit leaves Mara's own sound out of the capture
/// (`excludesCurrentProcessAudio`, measured: nothing of it reaches the meeting audio), so the voice
/// never comes back as captions. The microphone is another matter: on speakers it hears Mara, so
/// `onSpeakingChanged` lets the session pause it.
@MainActor
final class CaptionReader {
    var onSpeakingChanged: (Bool) -> Void = { _ in }
    /// Who said a piece, as far as it's known: the gender of their voice, their voice slot,
    /// and whether telling who it was is still under way (worth waiting a moment for).
    var speaker: (UUID) -> (gender: VoiceGender?, slot: Int, pending: Bool)? = { _ in nil }
    /// The language's voice for a gender and slot.
    var voiceFor: (VoiceGender, Int) -> String = { _, _ in "F1" }
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
    /// The previous piece's voice, kept when the pitch doesn't tell.
    private var lastGender: VoiceGender = .female

    /// How long to wait for who said a piece, counted from when it was cut.
    static let speakerWait: TimeInterval = 0.8
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

    /// A piece ready to play: its samples and the voice that read it.
    private struct Prepared {
        let item: ReadoutQueue.Item
        let samples: [Float]
    }

    /// Plays the pieces in order. While one plays, the next is already being synthesized, so
    /// there's no silence between the pieces of a sentence.
    private func drain() async {
        var upcoming: Prepared?
        while !Task.isCancelled {
            let current: Prepared
            if let ready = upcoming {
                current = ready
                upcoming = nil
            } else {
                guard let item = queue.next() else { return }
                guard let ready = await prepare(item) else { continue }
                current = ready
            }
            guard let synthesizer, !Task.isCancelled else { return }
            let playback = Task { await self.play(current.samples, sampleRate: synthesizer.sampleRate) }
            if let next = queue.next() { upcoming = await prepare(next) }
            await playback.value
            recentlySpoken.append((current.item.text, Date()))
            recentlySpoken.removeAll { Date().timeIntervalSince($0.endedAt) > 30 }
        }
    }

    private func prepare(_ item: ReadoutQueue.Item) async -> Prepared? {
        guard let synthesizer else { return nil }
        let who = await resolvedSpeaker(item)
        let gender = who?.gender ?? lastGender
        lastGender = gender
        let voice = voiceFor(gender, who?.slot ?? 0)
        let pace = speed * ReadoutQueue.boost(waiting: queue.waiting.count)
        let started = Date()
        guard let samples = try? await synthesizer.synthesize(item.text, voice: voice, language: language, speed: pace),
              !Task.isCancelled else { return nil }
        SessionLog.write("VOZ \(voice) \(SessionLog.ms(since: started)) atraso=\(SessionLog.ms(since: item.createdAt)) espera=\(queue.waiting.count) \(item.text)")
        return Prepared(item: item, samples: samples)
    }

    /// Who said it, once known. Telling the speaker apart takes about a quarter of a second; it's
    /// not waited for past `speakerWait`.
    private func resolvedSpeaker(_ item: ReadoutQueue.Item) async -> (gender: VoiceGender?, slot: Int)? {
        while let current = speaker(item.id), current.pending,
              Date().timeIntervalSince(item.createdAt) < Self.speakerWait, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(30))
        }
        return speaker(item.id).map { ($0.gender, $0.slot) }
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
        guard await download(engine.model) else { return }
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

    /// Feeds the folder's sentences, in a shuffled order, to the speaker tracker and prints who
    /// each one was given to, next to who really said it.
    static func runSpeakers(folder: URL) async {
        guard await download(.speakers) else { return }
        var started = Date()
        guard let tracker = try? await SpeakerTracker.load() else {
            print("could not load the speaker model")
            return
        }
        print("loaded and warmed up in \(SessionLog.ms(since: started))")
        let files = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "wav" }.shuffled()
        var given: [String: [Int]] = [:]
        for file in files {
            guard let audio = try? AVAudioFile(forReading: file, commonFormat: .pcmFormatFloat32, interleaved: false),
                  let buffer = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: AVAudioFrameCount(audio.length)),
                  (try? audio.read(into: buffer)) != nil else { continue }
            let samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
            // A caption sentence lasts a few seconds.
            let clip = Array(samples.prefix(Int(audio.processingFormat.sampleRate * 4)))
            started = Date()
            let info = await tracker.identify(clip, sampleRate: audio.processingFormat.sampleRate)
            let speaker = String(file.lastPathComponent.split(separator: "_")[0])
            given[speaker, default: []].append(info?.person ?? 0)
            print("\(speaker) -> person \(info?.person ?? 0) \(info?.gender?.rawValue ?? "?") slot \(info?.slot ?? 0) in \(SessionLog.ms(since: started))")
        }
        print("\nwho really spoke -> the person numbers given:")
        for (speaker, people) in given.sorted(by: { $0.key < $1.key }) { print("  \(speaker): \(people)") }
    }

    private static func download(_ model: VoiceModel) async -> Bool {
        let store = VoiceModelStore.shared
        guard store.state(model) != .ready else { return true }
        print("Downloading \(model.rawValue) (\(model.megabytes) MB)…")
        store.download(model)
        var last = -1
        while true {
            switch store.state(model) {
            case .downloading(let fraction):
                let percent = Int(fraction * 100)
                if percent / 10 != last / 10 { print("  \(percent)%") }
                last = percent
            case .ready:
                print("  downloaded and checked")
                return true
            case .failed(let message):
                print("  failed: \(message)")
                return false
            case .missing:
                print("  cancelled")
                return false
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
    }
}
