import AppKit
import AVFoundation
import Foundation

struct FocusProtectionSessionState: Equatable, Sendable {
    private(set) var isEnabled = false
    private(set) var hasActiveViolation = false

    mutating func enable() {
        isEnabled = true
        hasActiveViolation = false
    }

    mutating func recordViolation() -> Bool {
        guard isEnabled else { return false }
        let isNewViolation = !hasActiveViolation
        hasActiveViolation = true
        return isNewViolation
    }

    mutating func acknowledgeReturn() -> Bool {
        guard isEnabled, hasActiveViolation else { return false }
        hasActiveViolation = false
        return true
    }

    mutating func disable() {
        isEnabled = false
        hasActiveViolation = false
    }
}

enum FocusInterruptionReason: String, Equatable, Sendable {
    case applicationSwitch = "switched-application"
    case focusCheck = "focus-check"
    case leftFullscreen = "left-fullscreen"
    case focusNotRestored = "focus-not-restored"
    case systemSuspension = "system-suspension"

    var shouldSoundAlarm: Bool {
        self != .systemSuspension
    }
}

@MainActor
final class FocusAlarmPlayer {
    private var player: AVAudioPlayer?

    var isPlaying: Bool {
        player?.isPlaying == true
    }

    func start() {
        if player?.isPlaying == true { return }

        do {
            let nextPlayer = try AVAudioPlayer(data: Self.makeAlarmWaveData())
            nextPlayer.numberOfLoops = -1
            nextPlayer.volume = 1
            nextPlayer.prepareToPlay()
            nextPlayer.play()
            player = nextPlayer
        } catch {
            NSLog("TimeBoxer could not start the native focus alarm: %@", error.localizedDescription)
            NSSound.beep()
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    nonisolated static func makeAlarmWaveData() -> Data {
        let sampleRate: UInt32 = 44_100
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let loopDuration = 1.72
        let frameCount = Int(Double(sampleRate) * loopDuration)
        let bytesPerSample = Int(bitsPerSample / 8)
        let dataByteCount = frameCount * Int(channels) * bytesPerSample
        let tones: [(start: Double, duration: Double, frequency: Double)] = [
            (0.00, 0.34, 880),
            (0.40, 0.34, 660),
            (0.80, 0.42, 1_047),
            (1.28, 0.38, 784),
        ]

        var data = Data()
        data.appendASCII("RIFF")
        data.appendLittleEndian(UInt32(36 + dataByteCount))
        data.appendASCII("WAVE")
        data.appendASCII("fmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(channels)
        data.appendLittleEndian(sampleRate)
        data.appendLittleEndian(sampleRate * UInt32(channels) * UInt32(bytesPerSample))
        data.appendLittleEndian(channels * UInt16(bytesPerSample))
        data.appendLittleEndian(bitsPerSample)
        data.appendASCII("data")
        data.appendLittleEndian(UInt32(dataByteCount))

        for frame in 0..<frameCount {
            let time = Double(frame) / Double(sampleRate)
            var sample = 0.0

            for tone in tones where time >= tone.start && time <= tone.start + tone.duration {
                let localTime = time - tone.start
                let attack = min(1, localTime / 0.012)
                let release = min(1, (tone.start + tone.duration - time) / 0.035)
                let envelope = max(0, min(attack, release))
                let squareWave = sin(2 * .pi * tone.frequency * localTime) >= 0 ? 1.0 : -1.0
                sample += squareWave * 0.88 * envelope
            }

            let clamped = max(-1, min(1, sample))
            data.appendLittleEndian(Int16(clamped * Double(Int16.max)))
        }

        return data
    }
}

private extension Data {
    mutating func appendASCII(_ value: String) {
        append(value.data(using: .ascii) ?? Data())
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndianValue = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndianValue) { bytes in
            append(contentsOf: bytes)
        }
    }
}
