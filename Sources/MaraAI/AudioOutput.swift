import CoreAudio

/// Where the Mac's sound is coming out. When it's speakers, the microphone hears Mara reading, so
/// it pauses while she speaks; with headphones it doesn't need to.
enum AudioOutput {
    /// True for the Mac's own speakers, displays (HDMI, DisplayPort, AirPlay) and anything unknown;
    /// false for headphones: the headphone jack, Bluetooth and USB headsets.
    static var isSpeaker: Bool {
        guard let device = defaultOutputDevice else { return true }
        switch transportType(of: device) {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE, kAudioDeviceTransportTypeUSB:
            return false
        case kAudioDeviceTransportTypeBuiltIn:
            // On Macs with a headphone jack, the built-in device switches its data source.
            return dataSource(of: device) != headphonesSource
        default:
            return true
        }
    }

    /// 'hdpn', the built-in output's headphone data source.
    private static let headphonesSource: UInt32 = 0x6864_706E

    private static var defaultOutputDevice: AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr && device != 0 ? device : nil
    }

    private static func transportType(of device: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return value
    }

    private static func dataSource(of device: AudioDeviceID) -> UInt32? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDataSource,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value : nil
    }
}
