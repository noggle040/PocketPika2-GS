import Foundation
import AVFoundation

// Short procedural square-wave chirps for tactile audio feedback.
// Alberto-rp/Pocket-pikachu-emulator has no sound file to import (just a
// commented-out audioShaking.play() statement). These are ORIGINAL effects,
// deliberately not described as exact dumps of the Nintendo hardware.
enum PocketPikaTone: CaseIterable {
    case tap, wake, gift, bigGift, win, lose

    var notes: [(Double, Double)] {
        // frequencies (Hz), durations (seconds); 0 Hz denotes silence.
        switch self {
        case .tap: return [(880, 0.035)]
        case .wake: return [(650, 0.06), (0, 0.025), (800, 0.06)]
        case .gift: return [(740, 0.055), (0, 0.025), (980, 0.11)]
        case .bigGift: return [(660, 0.06), (880, 0.07), (1175, 0.13)]
        case .win: return [(990, 0.055), (1260, 0.095)]
        case .lose: return [(480, 0.10), (360, 0.14)]
        }
    }
}

@MainActor
final class PocketPikaSound {
    static let shared = PocketPikaSound()
    private var player: AVAudioPlayer?
    private init() {}

    func play(_ sound: PocketPikaTone) {
        guard UserDefaults.standard.object(forKey: "pocket-pika-gs.sound-enabled") as? Bool ?? true else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            let data = Self.makeWave(sound.notes)
            player = try AVAudioPlayer(data: data)
            player?.volume = 0.24
            player?.prepareToPlay()
            player?.play()
        } catch {
            // Sound is optional; a locked/muted phone must not interrupt the pet.
        }
    }

    private static func makeWave(_ tones: [(Double, Double)]) -> Data {
        let sampleRate = 16_000
        var samples: [Int16] = []
        for (frequency, seconds) in tones {
            let count = max(1, Int(seconds * Double(sampleRate)))
            for n in 0..<count {
                if frequency <= 0 { samples.append(0); continue }
                let phase = Double(n) * frequency / Double(sampleRate)
                let wave = (phase.truncatingRemainder(dividingBy: 1.0) < 0.5) ? 1.0 : -1.0
                let fade = min(min(1.0, Double(n) / 80.0), Double(count - n) / 120.0)
                samples.append(Int16(7_500 * wave * max(0, fade)))
            }
        }
        var bytes = Data()
        func put16(_ value: UInt16) {
            bytes.append(UInt8(truncatingIfNeeded: value))
            bytes.append(UInt8(truncatingIfNeeded: value >> 8))
        }
        func put32(_ value: UInt32) {
            bytes.append(UInt8(truncatingIfNeeded: value))
            bytes.append(UInt8(truncatingIfNeeded: value >> 8))
            bytes.append(UInt8(truncatingIfNeeded: value >> 16))
            bytes.append(UInt8(truncatingIfNeeded: value >> 24))
        }
        bytes.append(contentsOf: [82, 73, 70, 70]) // RIFF
        put32(UInt32(36 + samples.count * 2))
        bytes.append(contentsOf: [87, 65, 86, 69, 102, 109, 116, 32]) // WAVEfmt
        put32(16) // PCM format length
        put16(1)  // PCM
        put16(1)  // mono
        put32(UInt32(sampleRate))
        put32(UInt32(sampleRate * 2))
        put16(2) // bytes/frame
        put16(16)
        bytes.append(contentsOf: [100, 97, 116, 97]) // data
        put32(UInt32(samples.count * 2))
        for sample in samples { put16(UInt16(bitPattern: sample)) }
        return bytes
    }
}
