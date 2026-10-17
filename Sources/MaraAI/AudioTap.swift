import AppKit
import AVFoundation
import CoreAudio

/// A process that has an audio client in Core Audio: its object, pid and bundle, and whether it is
/// playing right now.
struct AudioProcess {
    let object: AudioObjectID
    let pid: pid_t
    let bundleID: String
    let isPlaying: Bool

    /// Every process Core Audio knows about.
    static func all() -> [AudioProcess] {
        let objects: [AudioObjectID] = CoreAudioProperty.array(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList)
        return objects.map { object in
            AudioProcess(
                object: object,
                pid: CoreAudioProperty.value(object, kAudioProcessPropertyPID) ?? -1,
                bundleID: CoreAudioProperty.string(object, kAudioProcessPropertyBundleID) ?? "",
                isPlaying: (CoreAudioProperty.value(object, kAudioProcessPropertyIsRunningOutput) as UInt32?) == 1
            )
        }
    }

    /// Mara's own process, to leave out of a tap of everything.
    static var current: AudioObjectID? {
        var pid = getpid()
        var object = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = CoreAudioProperty.address(kAudioHardwarePropertyTranslatePIDToProcessObject)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, UInt32(MemoryLayout<pid_t>.size), &pid, &size, &object)
        return status == noErr && object != kAudioObjectUnknown ? object : nil
    }

    /// The name of the app the process belongs to, when it has one.
    var appName: String {
        NSRunningApplication(processIdentifier: pid)?.localizedName ?? ""
    }

    /// The executable's file name, for processes without a bundle (afplay, say…).
    var executable: String {
        var path = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { return "" }
        return URL(fileURLWithPath: String(cString: path)).lastPathComponent
    }
}

/// Captures what one or more processes play (or everything but Mara) with a Core Audio process
/// tap, and can keep that sound from reaching the speakers while it is being read: the user hears
/// only what Mara plays, while Mara still hears the original. ScreenCaptureKit can only copy the
/// Mac's audio, never silence it.
///
/// The tap lives in a private aggregate device, read by an IO proc. Everything is torn down by
/// `stop()`, and Core Audio drops a private tap and device on its own when the process exits.
final class AudioTap {
    enum TapError: Error, CustomStringConvertible {
        case coreAudio(String, OSStatus)
        var description: String {
            switch self {
            case .coreAudio(let step, let status): return "\(step) failed (OSStatus \(status))"
            }
        }
    }

    private(set) var format: AVAudioFormat?
    private var tap = AudioObjectID(kAudioObjectUnknown)
    private var device = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "mara-ai.audio-tap", qos: .userInteractive)

    /// Taps `processes`, or everything except Mara when nil. `muted`: the tapped sound stops
    /// reaching the speakers while the tap is read (`.mutedWhenTapped`), and comes back as soon as
    /// it isn't.
    func start(processes: [AudioObjectID]?, muted: Bool, onBuffer: @escaping (AVAudioPCMBuffer, _ delay: Double) -> Void) throws {
        let description: CATapDescription
        if let processes {
            description = CATapDescription(stereoMixdownOfProcesses: processes)
        } else {
            description = CATapDescription(stereoGlobalTapButExcludeProcesses: AudioProcess.current.map { [$0] } ?? [])
        }
        description.uuid = UUID()
        description.name = "Mara AI"
        description.isPrivate = true
        description.muteBehavior = muted ? .mutedWhenTapped : .unmuted

        try check("AudioHardwareCreateProcessTap", AudioHardwareCreateProcessTap(description, &tap))

        var streamDescription: AudioStreamBasicDescription = try CoreAudioProperty.required(tap, kAudioTapPropertyFormat, step: "reading the tap's format")
        guard let format = AVAudioFormat(streamDescription: &streamDescription) else {
            throw TapError.coreAudio("making the tap's AVAudioFormat", -1)
        }
        self.format = format

        // The aggregate device needs a clock: the default output device's.
        let outputDevice: AudioObjectID = try CoreAudioProperty.required(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultSystemOutputDevice, step: "finding the output device")
        let outputUID = CoreAudioProperty.string(outputDevice, kAudioDevicePropertyDeviceUID) ?? ""
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Mara AI Tap",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true, kAudioSubTapUIDKey: description.uuid.uuidString]],
        ]
        try check("AudioHardwareCreateAggregateDevice", AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &device))

        try check("AudioDeviceCreateIOProcIDWithBlock", AudioDeviceCreateIOProcIDWithBlock(&procID, device, queue) { _, input, inputTime, _, _ in
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: input, deallocator: nil) else { return }
            // How long ago, at delivery, the first sample of this buffer was captured.
            let delay = inputTime.pointee.mFlags.contains(.hostTimeValid)
                ? Double(AudioConvertHostTimeToNanos(mach_absolute_time() &- inputTime.pointee.mHostTime)) / 1e9
                : -1
            onBuffer(buffer, delay)
        })
        try check("AudioDeviceStart", AudioDeviceStart(device, procID))
    }

    func stop() {
        if device != kAudioObjectUnknown {
            AudioDeviceStop(device, procID)
            if let procID { AudioDeviceDestroyIOProcID(device, procID) }
            AudioHardwareDestroyAggregateDevice(device)
        }
        if tap != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tap) }
        procID = nil
        device = AudioObjectID(kAudioObjectUnknown)
        tap = AudioObjectID(kAudioObjectUnknown)
    }

    deinit { stop() }

    private func check(_ step: String, _ status: OSStatus) throws {
        guard status == noErr else { throw TapError.coreAudio(step, status) }
    }
}

/// Reads Core Audio object properties without the pointer dance at every call.
enum CoreAudioProperty {
    static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }

    static func value<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> T? {
        var address = address(selector)
        var size = UInt32(MemoryLayout<T>.size)
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<T>.alignment)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer) == noErr else { return nil }
        return pointer.load(as: T.self)
    }

    static func required<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, step: String) throws -> T {
        guard let value: T = value(object, selector) else { throw AudioTap.TapError.coreAudio(step, -1) }
        return value
    }

    static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = address(selector)
        var size = UInt32(MemoryLayout<CFString?>.size)
        var value: Unmanaged<CFString>?
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    static func array<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [T] {
        var address = address(selector)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<T>.stride
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: count)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer) == noErr else { return [] }
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }
}

/// `MaraAI --try-tap <app|all> [seconds] [--unmuted]`: taps an app's audio (or everything but Mara)
/// and prints, each second, how loud it is, how many buffers came in all zeros and how late they
/// arrive. Muted by default: the tapped app should go silent on the speakers for those seconds.
enum TapTrial {
    static func run(target: String, seconds: Double, muted: Bool) {
        let processes = AudioProcess.all()
        print("Audio processes (▶ = playing now):")
        for process in processes where !process.bundleID.isEmpty || process.isPlaying {
            print("  \(process.isPlaying ? "▶" : " ") pid \(process.pid) \(process.bundleID.isEmpty ? process.executable : process.bundleID) \(process.appName)")
        }

        let chosen: [AudioObjectID]?
        if target == "all" {
            chosen = nil
            print("\nTapping everything except Mara, \(muted ? "muted" : "unmuted"), for \(Int(seconds)) s")
        } else {
            let matches = processes.filter { process in
                let needle = target.lowercased()
                return String(process.pid) == target || process.bundleID.lowercased().contains(needle)
                    || process.appName.lowercased().contains(needle) || process.executable.lowercased() == needle
                    // Safari and other WebKit apps play through WebKit's GPU process.
                    || (needle.contains("safari") && process.bundleID.hasPrefix("com.apple.WebKit.GPU"))
            }
            guard !matches.isEmpty else {
                print("\nNo audio process matches \"\(target)\". Start playing something in it first.")
                return
            }
            chosen = matches.map(\.object)
            print("\nTapping \(matches.map { "\($0.bundleID) (\($0.pid))" }.joined(separator: ", ")), \(muted ? "muted" : "unmuted"), for \(Int(seconds)) s")
        }

        let meter = TapMeter()
        let tap = AudioTap()
        do {
            try tap.start(processes: chosen, muted: muted) { buffer, delay in meter.add(buffer, delay: delay) }
        } catch {
            print("Could not start the tap: \(error)")
            return
        }
        if let format = tap.format {
            print("Tap format: \(Int(format.sampleRate)) Hz, \(format.channelCount) ch, \(format.isInterleaved ? "interleaved" : "non-interleaved")")
        }
        let started = Date()
        while Date().timeIntervalSince(started) < seconds {
            Thread.sleep(forTimeInterval: 1)
            print(meter.report())
        }
        tap.stop()
        print("Tap stopped and destroyed: the sound should be back on the speakers.")
    }
}

/// Levels of the tapped audio, collected on the IO queue and reported once a second.
private final class TapMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var buffers = 0
    private var silent = 0
    private var frames = 0
    private var sumSquares = 0.0
    private var peak: Float = 0
    private var delays: [Double] = []

    func add(_ buffer: AVAudioPCMBuffer, delay: Double) {
        guard let channels = buffer.floatChannelData else { return }
        let count = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        // Interleaved (as taps deliver it): all channels in the first array, one after another.
        let arrays = buffer.format.isInterleaved ? 1 : channelCount
        let perArray = buffer.format.isInterleaved ? count * channelCount : count
        var squares = 0.0
        var top: Float = 0
        for array in 0..<arrays {
            for index in 0..<perArray {
                let sample = channels[array][index]
                squares += Double(sample * sample)
                top = max(top, abs(sample))
            }
        }
        lock.lock()
        defer { lock.unlock() }
        buffers += 1
        if top == 0 { silent += 1 }
        frames += count * channelCount
        sumSquares += squares
        peak = max(peak, top)
        if delay >= 0 { delays.append(delay) }
    }

    func report() -> String {
        lock.lock()
        defer {
            buffers = 0; silent = 0; frames = 0; sumSquares = 0; peak = 0; delays = []
            lock.unlock()
        }
        let rms = frames > 0 ? sqrt(sumSquares / Double(frames)) : 0
        let decibels = rms > 0 ? 20 * log10(rms) : -.infinity
        let sorted = delays.sorted()
        let median = sorted.isEmpty ? -1 : sorted[sorted.count / 2] * 1000
        return String(format: "  %3d buffers, %3d all zeros, RMS %6.1f dBFS, peak %.3f, delay %.1f ms", buffers, silent, decibels, peak, median)
    }
}
