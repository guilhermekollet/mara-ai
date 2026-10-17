import AppKit
import AVFoundation
import CoreAudio

/// What "hear only the dubbing" keeps off the speakers.
enum DubbingTarget: Equatable {
    /// Every app but Mara.
    case everything
    /// One app, with the helper processes that play for it. A browser goes silent as a whole: all
    /// its tabs play through one process (see docs/dubbing-only-mode.md).
    case app(bundleID: String)

    /// Saved as the app's bundle identifier, or "*" for every app.
    init(storage: String) {
        self = storage.isEmpty || storage == "*" ? .everything : .app(bundleID: storage)
    }

    var storage: String {
        if case .app(let bundleID) = self { return bundleID }
        return "*"
    }
}

/// An app that has audio in Core Audio, for the picker in Settings.
struct AudioApp: Identifiable, Hashable {
    let bundleID: String
    let name: String
    let isPlaying: Bool
    var id: String { bundleID }
}

/// Maps Core Audio's processes to the apps they play for. Helpers live inside their app's bundle
/// (Chrome's audio service is ".../Google Chrome.app/Contents/Frameworks/.../Google Chrome
/// Helper.app"), so the outermost ".app" in the executable's path is the app. WebKit's GPU process,
/// a system service, plays Safari's media. Works from any thread: no list of running apps needed.
enum AudioApps {
    static let safari = "com.apple.Safari"

    /// The outermost app bundle in an executable's path, if it is inside one.
    static func outermostApp(inPath path: String) -> String? {
        var components: [String] = []
        for component in path.split(separator: "/", omittingEmptySubsequences: false) {
            components.append(String(component))
            if component.hasSuffix(".app") { return components.joined(separator: "/") }
        }
        return nil
    }

    /// The bundle identifier of the app `process` plays for, or nil for a background service. The
    /// system's own apps (loginwindow, Siri, the power chime) aren't meeting apps.
    static func owner(of process: AudioProcess) -> String? {
        if process.bundleID.hasPrefix("com.apple.WebKit.") { return safari }
        guard let app = outermostApp(inPath: process.path), !isSystemApp(app) else { return nil }
        return Bundle(path: app)?.bundleIdentifier
    }

    static func isSystemApp(_ path: String) -> Bool {
        path.hasPrefix("/System/Library/")
    }

    /// The apps with audio in Core Audio now, Mara left out, the ones playing first.
    static func current() -> [AudioApp] {
        var playing: [String: Bool] = [:]
        for process in AudioProcess.all() {
            guard let owner = owner(of: process), owner != Bundle.main.bundleIdentifier else { continue }
            playing[owner] = (playing[owner] ?? false) || process.isPlaying
        }
        return playing.map { id, isPlaying in AudioApp(bundleID: id, name: name(of: id), isPlaying: isPlaying) }
            .sorted { ($0.isPlaying ? 0 : 1, $0.name) < ($1.isPlaying ? 0 : 1, $1.name) }
    }

    /// The Core Audio processes that play for `app` now.
    static func processes(of app: String) -> [AudioProcess] {
        AudioProcess.all().filter { owner(of: $0) == app }
    }

    /// The app's name as Finder shows it.
    static func name(of bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}

/// Tells a tap that stopped delivering audio from a quiet meeting. Taps have been seen to keep
/// firing with every sample at exactly zero while the app was audible. ScreenCaptureKit, which
/// keeps running alongside, still hears what the tap keeps off the speakers (measured), so when it
/// hears sound the tap should have and the tap brings only zeros, for long enough, the tap is broken.
struct TapHealth {
    static let patience: TimeInterval = 5

    private var brokenSince: Date?

    /// Called once a second. `tapSilent`: the tap delivered only exact zeros in that second.
    /// `soundExpected`: ScreenCaptureKit heard sound the tap should have carried. True once the
    /// two have disagreed for `patience` seconds in a row.
    mutating func update(tapSilent: Bool, soundExpected: Bool, now: Date = Date()) -> Bool {
        guard tapSilent, soundExpected else {
            brokenSince = nil
            return false
        }
        let since = brokenSince ?? now
        brokenSince = since
        return now.timeIntervalSince(since) >= Self.patience
    }
}

/// "Hear only the dubbing": captures the meeting with a Core Audio process tap that keeps it off
/// the speakers, so the user hears only Mara reading the translation aloud, and plays the
/// original underneath at `originalVolume`. ScreenCaptureKit keeps running alongside: it feeds the
/// captions whenever the tap doesn't (the app hasn't played yet, the output device is changing),
/// and it is the witness that tells a broken tap, which then gives the sound back for good.
final class DubbingCapture: @unchecked Sendable {
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "mara-ai.dubbing")
    private let onBuffer: (AVAudioPCMBuffer) -> Void
    private let onFallback: @MainActor () -> Void
    private let original = OriginalPlayback()

    // On `queue`.
    private var target: DubbingTarget?
    private var tap: AudioTap?
    private var tapped: [AudioProcess] = []
    private var clock: AudioObjectID?
    private var health = TapHealth()
    private var timer: DispatchSourceTimer?
    private var listeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    // Under `lock`: shared with the tap's IO queue and the capture queue.
    private var feeding = false
    private var tapPeak: Float = 0
    private var screenLevel: Double = 0

    /// `onBuffer` gets the tapped audio on the tap's queue, only valid during the call.
    init(onBuffer: @escaping (AVAudioPCMBuffer) -> Void, onFallback: @escaping @MainActor () -> Void) {
        self.onBuffer = onBuffer
        self.onFallback = onFallback
    }

    /// Whether the captions come from the tap right now (otherwise from ScreenCaptureKit).
    var isFeeding: Bool {
        lock.lock()
        defer { lock.unlock() }
        return feeding
    }

    /// Turns the mode on for `target`, off with nil. Changing the volume alone keeps the tap.
    func set(_ target: DubbingTarget?, originalVolume: Double) {
        original.volume = Float(originalVolume)
        queue.async { [self] in
            guard target != self.target else { return }
            tearDown()
            self.target = target
            guard target != nil else { return }
            listen()
            rebuild()
            startHealthChecks()
        }
    }

    func stop() {
        queue.sync { [self] in
            tearDown()
            target = nil
        }
    }

    /// ScreenCaptureKit's copy of the Mac's audio, from the capture queue: how loud it is.
    func noteScreenAudio(_ buffer: AVAudioPCMBuffer) {
        let level = Self.rms(of: buffer)
        lock.lock()
        screenLevel = max(screenLevel, level)
        lock.unlock()
    }

    // MARK: On `queue`

    /// (Re)creates the tap when what it should capture changed: the app started or stopped
    /// playing through a new process, or the output device clocking it changed.
    private func rebuild() {
        guard let target else { return }
        let processes: [AudioProcess]?
        switch target {
        case .everything: processes = nil
        case .app(let bundleID): processes = AudioApps.processes(of: bundleID)
        }
        let device = AudioTap.defaultOutputDevice
        if tap != nil, device == clock, processes?.map(\.object) == tapped.map(\.object) { return }
        stopTap()
        // The app has no audio yet: ScreenCaptureKit carries on until it plays.
        if let processes, processes.isEmpty { return }
        let tap = AudioTap()
        do {
            try tap.start(processes: processes?.map(\.object), muted: true) { [weak self] buffer, _ in
                self?.receive(buffer)
            }
        } catch {
            log("DUBLAGEM tap não abriu: \(error)")
            return
        }
        self.tap = tap
        tapped = processes ?? []
        clock = device
        health = TapHealth()
        setFeeding(true)
        original.start(format: tap.format)
        let what = processes.map { $0.map { "\($0.bundleID) (\($0.pid))" }.joined(separator: ", ") } ?? "tudo menos a Mara"
        log("DUBLAGEM tap aberto: \(what)")
    }

    private func stopTap() {
        setFeeding(false)
        tap?.stop()
        tap = nil
        tapped = []
        original.stop()
    }

    private func tearDown() {
        timer?.cancel()
        timer = nil
        let system = AudioObjectID(kAudioObjectSystemObject)
        for (address, block) in listeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(system, &address, queue, block)
        }
        listeners = []
        stopTap()
    }

    /// Rebuilds when processes come and go (an app that starts playing gets its first audio
    /// client) and when the default output changes (headphones in, AirPods connecting).
    private func listen() {
        let system = AudioObjectID(kAudioObjectSystemObject)
        for selector in [kAudioHardwarePropertyProcessObjectList, kAudioHardwarePropertyDefaultOutputDevice] {
            var address = CoreAudioProperty.address(selector)
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.rebuild() }
            if AudioObjectAddPropertyListenerBlock(system, &address, queue, block) == noErr {
                listeners.append((address, block))
            }
        }
    }

    private func startHealthChecks() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in self?.checkHealth() }
        timer.resume()
        self.timer = timer
    }

    private func checkHealth() {
        lock.lock()
        let peak = tapPeak
        let level = screenLevel
        tapPeak = 0
        screenLevel = 0
        lock.unlock()
        guard let target, tap != nil else { return }
        // ScreenCaptureKit hears every app: in app mode, only its sound counts while the app plays.
        let appPlaying = target == .everything || tapped.contains { process in
            (CoreAudioProperty.value(process.object, kAudioProcessPropertyIsRunningOutput) as UInt32?) == 1
        }
        let expected = level > Self.soundLevel && appPlaying
        guard health.update(tapSilent: peak == 0, soundExpected: expected) else { return }
        log("DUBLAGEM tap só entrega zeros: som devolvido ao alto-falante")
        tearDown()
        self.target = nil
        let onFallback = onFallback
        Task { @MainActor in onFallback() }
    }

    /// The session log lives on the main actor.
    private func log(_ text: String) {
        Task { @MainActor in SessionLog.write(text) }
    }

    // MARK: Tap's IO queue

    private func receive(_ buffer: AVAudioPCMBuffer) {
        let peak = Self.peak(of: buffer)
        lock.lock()
        tapPeak = max(tapPeak, peak)
        let feeding = feeding
        lock.unlock()
        guard feeding else { return }
        onBuffer(buffer)
        original.push(buffer)
    }

    private func setFeeding(_ value: Bool) {
        lock.lock()
        feeding = value
        lock.unlock()
    }

    /// The level from which ScreenCaptureKit's audio counts as sound, as `ActivityGate` judges it.
    private static let soundLevel = 0.006

    private static func samples(of buffer: AVAudioPCMBuffer) -> [UnsafeBufferPointer<Float>] {
        guard let channels = buffer.floatChannelData else { return [] }
        let frames = Int(buffer.frameLength)
        let count = Int(buffer.format.channelCount)
        if buffer.format.isInterleaved {
            return [UnsafeBufferPointer(start: channels[0], count: frames * count)]
        }
        return (0..<count).map { UnsafeBufferPointer(start: channels[$0], count: frames) }
    }

    static func peak(of buffer: AVAudioPCMBuffer) -> Float {
        samples(of: buffer).reduce(0) { top, channel in channel.reduce(top) { max($0, abs($1)) } }
    }

    static func rms(of buffer: AVAudioPCMBuffer) -> Double {
        var sum = 0.0
        var count = 0
        for channel in samples(of: buffer) {
            for sample in channel { sum += Double(sample * sample) }
            count += channel.count
        }
        return count > 0 ? (sum / Double(count)).squareRoot() : 0
    }
}

/// Plays the tapped original quietly under the dubbing, through Mara's own audio engine. Mara is
/// never in what it taps (an app other than Mara, or everything but Mara) and ScreenCaptureKit
/// leaves Mara out too, so this sound never comes back into the captions.
final class OriginalPlayback: @unchecked Sendable {
    private let lock = NSLock()
    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var format: AVAudioFormat?
    /// Interleaved samples, a second's worth, read by the render block as they come in.
    private var ring: [Float] = []
    private var readIndex = 0
    private var available = 0
    private var channels = 2
    /// More than this waiting (a hiccup in the output) is dropped, so the original stays in step.
    private static let maxLatency = 0.15

    var volume: Float = 0 {
        didSet {
            engine.mainMixerNode.outputVolume = volume
            lock.lock()
            let format = format
            lock.unlock()
            if volume == 0 {
                engine.pause()
            } else if format != nil, !engine.isRunning {
                try? engine.start()
            }
        }
    }

    /// Gets ready for the tap's audio. Starts playing only with a volume above zero.
    func start(format tapFormat: AVAudioFormat?) {
        guard let tapFormat, let output = AVAudioFormat(standardFormatWithSampleRate: tapFormat.sampleRate, channels: tapFormat.channelCount) else { return }
        stop()
        lock.lock()
        channels = Int(tapFormat.channelCount)
        ring = [Float](repeating: 0, count: Int(tapFormat.sampleRate) * channels)
        readIndex = 0
        available = 0
        format = output
        lock.unlock()
        let node = AVAudioSourceNode(format: output) { [weak self] _, _, frameCount, bufferList in
            self?.render(Int(frameCount), into: UnsafeMutableAudioBufferListPointer(bufferList))
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: output)
        source = node
        engine.mainMixerNode.outputVolume = volume
        if volume > 0 { try? engine.start() }
    }

    func stop() {
        engine.stop()
        if let source {
            engine.detach(source)
            self.source = nil
        }
        lock.lock()
        format = nil
        available = 0
        lock.unlock()
    }

    /// The tap's audio, on its IO queue.
    func push(_ buffer: AVAudioPCMBuffer) {
        guard volume > 0, let data = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        let count = Int(buffer.format.channelCount)
        lock.lock()
        defer { lock.unlock() }
        guard format != nil, count == channels, !ring.isEmpty else { return }
        let capacity = ring.count
        var write = (readIndex + available) % capacity
        for frame in 0..<frames {
            for channel in 0..<count {
                ring[write] = buffer.format.isInterleaved ? data[0][frame * count + channel] : data[channel][frame]
                write = (write + 1) % capacity
            }
        }
        available = min(available + frames * count, capacity)
        let limit = Int(Self.maxLatency * buffer.format.sampleRate) * count
        if available > limit {
            readIndex = (readIndex + available - limit) % capacity
            available = limit
        }
    }

    private func render(_ frames: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
        lock.lock()
        defer { lock.unlock() }
        let capacity = ring.count
        for frame in 0..<frames {
            for channel in 0..<min(channels, buffers.count) {
                let out = buffers[channel].mData!.assumingMemoryBound(to: Float.self)
                if available > 0, capacity > 0 {
                    out[frame] = ring[(readIndex + channel) % capacity]
                } else {
                    out[frame] = 0
                }
            }
            if available > 0, capacity > 0 {
                readIndex = (readIndex + channels) % capacity
                available -= channels
            }
        }
    }
}

/// `MaraAI --try-dubbing <bundle id|all> <seconds> <original volume>...`: runs "hear only the
/// dubbing" on its own, with ScreenCaptureKit alongside as in a session, one step of `seconds`
/// per original volume given (0 = silent). Prints each second which source would feed the
/// captions and how loud each one is.
@MainActor
enum DubbingTrial {
    static func run(target: String, seconds: Double, volumes: [Double]) async {
        print("Apps with audio:")
        for app in AudioApps.current() { print("  \(app.isPlaying ? "▶" : " ") \(app.bundleID) \(app.name)") }
        let tapMeter = TapMeter()
        let screenMeter = TapMeter()
        let dubbing = DubbingCapture(onBuffer: { tapMeter.add($0, delay: -1) }, onFallback: { print("FALLBACK: the tap went silent, sound given back") })
        let screen = SystemAudioCapture()
        do {
            try await screen.start(
                microphone: false,
                onBuffer: { buffer in
                    dubbing.noteScreenAudio(buffer)
                    screenMeter.add(buffer, delay: -1)
                },
                onMicrophone: { _ in }, onMicrophoneLost: {},
                // As a session does: macOS interrupts capture now and then, and it is reopened.
                onStop: { error in
                    print("ScreenCaptureKit interrupted (\(error.localizedDescription)), reopening")
                    Task { try? await screen.restart() }
                }
            )
        } catch {
            print("ScreenCaptureKit didn't start: \(error)")
            return
        }
        let chosen = target == "all" ? DubbingTarget.everything : .app(bundleID: target)
        for volume in volumes {
            print("\n\(chosen.storage), original at \(Int(volume * 100))% for \(Int(seconds)) s")
            dubbing.set(chosen, originalVolume: volume)
            for _ in 0..<Int(seconds) {
                try? await Task.sleep(for: .seconds(1))
                print("  \(dubbing.isFeeding ? "tap feeds" : "sck feeds") | tap\(tapMeter.report()) | sck\(screenMeter.report())")
            }
        }
        dubbing.stop()
        await screen.stop()
        print("\nStopped: the sound should be back on the speakers.")
    }
}
