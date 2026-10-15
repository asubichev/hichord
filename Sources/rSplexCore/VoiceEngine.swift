import Foundation

/// Envelope times in seconds; sustain is a level 0…1.
public struct ADSR: Equatable {
    public var attack, decay, sustain, release: Double
    public init(_ attack: Double, _ decay: Double, _ sustain: Double, _ release: Double) {
        self.attack = attack; self.decay = decay; self.sustain = sustain; self.release = release
    }
}

/// CLASSIC is the original rSplex envelope; the rest follow common pad/stab/pluck shapes.
public let envelopePresets: [(name: String, adsr: ADSR)] = [
    ("CLASSIC", ADSR(0.005, 0, 1, 0.3)),
    ("LONG", ADSR(0.8, 1.0, 0.7, 2.0)),
    ("SHORT", ADSR(0.1, 0.1, 1.0, 0.12)),
    ("SWELL", ADSR(0.8, 0.3, 0.8, 2.0)),
    ("PLUCK", ADSR(0.005, 0.08, 0, 0.18)),
    ("TOUCH", ADSR(0.025, 0.26, 0.66, 0.45)),
    ("SUSTAIN", ADSR(0.2, 0.3, 0.85, 3.0)),
]

public let bpmRange = 40.0...300.0

public enum VoiceEvent: Equatable {
    /// Note, envelope, and gain (1 = a note in a triad; bigger chords pass 3/n to keep the original loudness).
    case noteOn(Int, ADSR, gain: Double = 1)
    case noteOff(Int)
    case allNotesOff
    case setBPM(Double)
}

/// Notes to stop and start to go from one set of sounding notes to another; shared notes keep ringing.
public func chordDiff(from old: Set<Int>, to new: Set<Int>) -> (off: [Int], on: [Int]) {
    (old.subtracting(new).sorted(), new.subtracting(old).sorted())
}

public func midiToHz(_ n: Int) -> Double { 440 * pow(2, Double(n - 69) / 12) }

/// Polyphonic synth: a fixed pool of voices, each with its own envelope, plus a beat clock.
/// Single-threaded and allocation-free while rendering, so it runs inside the audio callback.
public struct VoiceEngine {
    public enum Stage { case idle, attack, decay, sustain, release }

    public struct Voice {
        public var note = 0
        public var stage = Stage.idle
        public var level = 0.0
        var adsr = envelopePresets[0].adsr
        var gain = 1.0
        var releaseFrom = 0.0
        var phases = (0.0, 0.0)
        var freq = 0.0
        var startedAt: Int64 = 0
    }

    /// Per-voice gain: a triad sums to the original engine's loudness.
    public static let voiceGain = 0.35 / 3

    public let sampleRate: Double
    public private(set) var voices: [Voice]
    public private(set) var bpm = 120.0
    /// Beats elapsed since the engine started, integrated sample by sample so tempo changes stay in phase.
    public private(set) var beats = 0.0
    public private(set) var sampleTime: Int64 = 0
    private var lp = 0.0

    public init(sampleRate: Double, voiceCount: Int = 16) {
        self.sampleRate = sampleRate
        voices = Array(repeating: Voice(), count: voiceCount)
    }

    public var activeNotes: [Int] { voices.filter { $0.stage != .idle }.map(\.note).sorted() }
    public func voice(for note: Int) -> Voice? { voices.first { $0.stage != .idle && $0.note == note } }

    public mutating func handle(_ e: VoiceEvent) {
        switch e {
        case .noteOn(let n, let adsr, let gain): noteOn(n, adsr, gain)
        case .noteOff(let n):
            for i in voices.indices where voices[i].note == n && voices[i].stage != .idle && voices[i].stage != .release {
                startRelease(i)
            }
        case .allNotesOff:
            for i in voices.indices where voices[i].stage != .idle && voices[i].stage != .release { startRelease(i) }
        case .setBPM(let b): bpm = min(bpmRange.upperBound, max(bpmRange.lowerBound, b))
        }
    }

    private mutating func startRelease(_ i: Int) {
        voices[i].releaseFrom = voices[i].level
        voices[i].stage = .release
    }

    private mutating func noteOn(_ n: Int, _ adsr: ADSR, _ gain: Double) {
        // Reuse this note's voice if it's still ringing, else a free one, else steal: quietest releasing, then oldest.
        let i = voices.firstIndex { $0.stage != .idle && $0.note == n }
            ?? voices.firstIndex { $0.stage == .idle }
            ?? stealIndex()
        if voices[i].stage == .idle || voices[i].note != n { voices[i].phases = (0, 0); voices[i].level = 0 }
        voices[i].note = n
        voices[i].freq = midiToHz(n)
        voices[i].adsr = adsr
        voices[i].gain = gain
        voices[i].stage = .attack   // from the current level, so a retrigger or steal doesn't click
        voices[i].startedAt = sampleTime
    }

    private func stealIndex() -> Int {
        var quietest: Int?, oldest = 0
        for i in voices.indices {
            if voices[i].stage == .release, quietest.map({ voices[i].level < voices[$0].level }) ?? true { quietest = i }
            if voices[i].startedAt < voices[oldest].startedAt { oldest = i }
        }
        return quietest ?? oldest
    }

    private mutating func advanceEnvelope(_ i: Int) {
        let sr = sampleRate
        var v = voices[i]
        switch v.stage {
        case .idle: break
        case .attack:
            v.level = v.adsr.attack > 0 ? v.level + 1 / (v.adsr.attack * sr) : 1
            if v.level >= 1 { v.level = 1; v.stage = .decay }
        case .decay:
            v.level = v.adsr.decay > 0 ? v.level - (1 - v.adsr.sustain) / (v.adsr.decay * sr) : v.adsr.sustain
            if v.level <= v.adsr.sustain { v.level = v.adsr.sustain; v.stage = v.adsr.sustain > 0 ? .sustain : .idle }
        case .sustain:
            v.level = v.adsr.sustain
        case .release:
            v.level = v.adsr.release > 0 ? v.level - v.releaseFrom / (v.adsr.release * sr) : 0
            if v.level <= 0 { v.level = 0; v.stage = .idle }
        }
        voices[i] = v
    }

    /// Renders `frames` mono samples into `out`.
    public mutating func render(frames: Int, into out: UnsafeMutablePointer<Float>) {
        let sr = sampleRate
        for f in 0..<frames {
            var s = 0.0
            for i in voices.indices where voices[i].stage != .idle {
                advanceEnvelope(i)
                let v = voices[i]
                // Each note is a saw/sine blend plus a slightly detuned partner.
                var (p0, p1) = v.phases
                p0 += v.freq * 0.9985 / sr; if p0 >= 1 { p0 -= 1 }
                p1 += v.freq * 1.0015 / sr; if p1 >= 1 { p1 -= 1 }
                voices[i].phases = (p0, p1)
                let osc = 0.25 * (2 * p0 - 1) + 0.25 * sin(2 * .pi * p0) + 0.25 * (2 * p1 - 1) + 0.25 * sin(2 * .pi * p1)
                s += osc * v.level * v.gain * Self.voiceGain
            }
            lp += 0.2 * (s - lp)
            out[f] = Float(Self.softClip(lp))
            beats += bpm / 60 / sr
            sampleTime += 1
        }
    }

    /// Unchanged below 0.8; above, eases toward 1 so big chords can't clip.
    public static func softClip(_ x: Double) -> Double {
        let a = abs(x)
        return a <= 0.8 ? x : (x < 0 ? -1 : 1) * (0.8 + 0.2 * tanh((a - 0.8) / 0.2))
    }
}

/// Tap tempo: three or more taps set the BPM from the average of the last few intervals.
public struct TapTempo {
    public static let resetGap = 2.0
    private var taps: [Double] = []
    public init() {}

    /// Returns the new BPM once there are enough taps.
    public mutating func tap(at t: Double) -> Double? {
        if let last = taps.last, t - last > Self.resetGap { taps.removeAll() }
        taps.append(t)
        if taps.count > 5 { taps.removeFirst() }
        guard taps.count >= 3 else { return nil }
        let interval = (taps.last! - taps.first!) / Double(taps.count - 1)
        return min(bpmRange.upperBound, max(bpmRange.lowerBound, 60 / interval))
    }
}
