import XCTest
import AVFoundation
@testable import TimeBoxerMac

final class FocusProtectionTests: XCTestCase {
    func testUnpairedFocusSessionStillRecordsViolationWhenEnabled() {
        var session = FocusProtectionSessionState()

        session.enable()

        XCTAssertTrue(session.recordViolation())
        XCTAssertTrue(session.hasActiveViolation)
    }

    func testRepeatedSwitchesKeepViolationActiveWithoutDuplicatingFirstAlert() {
        var session = FocusProtectionSessionState()
        session.enable()

        XCTAssertTrue(session.recordViolation())
        XCTAssertFalse(session.recordViolation())
        XCTAssertTrue(session.hasActiveViolation)
    }

    func testAlarmCanOnlyBeAcknowledgedAfterAViolation() {
        var session = FocusProtectionSessionState()
        session.enable()

        XCTAssertFalse(session.acknowledgeReturn())
        _ = session.recordViolation()
        XCTAssertTrue(session.acknowledgeReturn())
        XCTAssertFalse(session.hasActiveViolation)
    }

    func testDisabledFocusSessionIgnoresSwitches() {
        var session = FocusProtectionSessionState()
        session.enable()
        session.disable()

        XCTAssertFalse(session.recordViolation())
        XCTAssertFalse(session.isEnabled)
        XCTAssertFalse(session.hasActiveViolation)
    }

    func testNativeAlarmIsAReusableLoopableWave() throws {
        let waveData = FocusAlarmPlayer.makeAlarmWaveData()
        let player = try AVAudioPlayer(data: waveData)

        XCTAssertGreaterThan(waveData.count, 100_000)
        XCTAssertGreaterThan(player.duration, 1.6)
        XCTAssertLessThan(player.duration, 1.8)
    }

    func testUserInitiatedFocusViolationsSoundTheAlarm() {
        XCTAssertTrue(FocusInterruptionReason.applicationSwitch.shouldSoundAlarm)
        XCTAssertTrue(FocusInterruptionReason.focusCheck.shouldSoundAlarm)
        XCTAssertTrue(FocusInterruptionReason.leftFullscreen.shouldSoundAlarm)
        XCTAssertTrue(FocusInterruptionReason.focusNotRestored.shouldSoundAlarm)
    }

    func testSystemSuspensionPausesEarnWithoutSoundingAlarm() {
        XCTAssertFalse(FocusInterruptionReason.systemSuspension.shouldSoundAlarm)
    }
}
