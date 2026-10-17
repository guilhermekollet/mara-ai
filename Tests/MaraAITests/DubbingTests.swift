import Testing
@testable import MaraAI

@Suite("Hearing only the dubbing")
struct DubbingTests {
    @Test func aHelperBelongsToTheAppAroundIt() {
        #expect(AudioApps.outermostApp(inPath: "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/1/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper")
            == "/Applications/Google Chrome.app")
        #expect(AudioApps.outermostApp(inPath: "/Applications/zoom.us.app/Contents/MacOS/zoom.us") == "/Applications/zoom.us.app")
    }

    @Test func aServiceOutsideAnyAppHasNone() {
        #expect(AudioApps.outermostApp(inPath: "/usr/bin/afplay") == nil)
        #expect(AudioApps.outermostApp(inPath: "/System/Library/Frameworks/WebKit.framework/Versions/A/XPCServices/com.apple.WebKit.GPU.xpc/Contents/MacOS/com.apple.WebKit.GPU") == nil)
        #expect(AudioApps.outermostApp(inPath: "") == nil)
    }

    @Test func theSystemsOwnAppsArentMeetingApps() {
        #expect(AudioApps.isSystemApp("/System/Library/CoreServices/loginwindow.app"))
        #expect(!AudioApps.isSystemApp("/Applications/zoom.us.app"))
        #expect(!AudioApps.isSystemApp("/System/Applications/FaceTime.app"))
    }

    @Test func theTargetIsSavedAsTheAppOrAStar() {
        #expect(DubbingTarget(storage: "*") == .everything)
        #expect(DubbingTarget(storage: "") == .everything)
        #expect(DubbingTarget(storage: "us.zoom.xos") == .app(bundleID: "us.zoom.xos"))
        #expect(DubbingTarget.app(bundleID: "us.zoom.xos").storage == "us.zoom.xos")
        #expect(DubbingTarget.everything.storage == "*")
    }

    @Test func aTapThatHearsNothingWhileTheMeetingIsAudibleIsBrokenAfterAWhile() {
        let patience = Int(TapHealth.patience)
        let verdicts = tapHealthVerdicts(Array(repeating: (true, true), count: patience + 1))
        #expect(verdicts.prefix(patience).allSatisfy { !$0 })
        #expect(verdicts.last == true)
    }

    @Test func aQuietMeetingIsntABrokenTap() {
        // Nobody speaking: the tap is silent, and so is ScreenCaptureKit.
        #expect(tapHealthVerdicts(Array(repeating: (true, false), count: 20)).allSatisfy { !$0 })
    }

    @Test func soundFromTheTapStartsTheCountOver() {
        let steps = Array(repeating: (true, true), count: 4) + [(false, true)] + Array(repeating: (true, true), count: 4)
        #expect(tapHealthVerdicts(steps).allSatisfy { !$0 })
    }
}
