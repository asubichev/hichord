import Foundation

/// One sequencer step: a chord as it was played (degree, held modifier, slash-bass degree). The notes are worked
/// out at playback, so changing key, scale, octave, voicing, or bass mode changes the whole sequence.
public struct SeqStep: Equatable {
    public var degree: Int
    public var mod: Int?
    /// Bass degree for a slash chord (SLASH bass with two chord keys held), else nil.
    public var slash: Int?
    public init(degree: Int, mod: Int? = nil, slash: Int? = nil) { self.degree = degree; self.mod = mod; self.slash = slash }
}

/// How long each step lasts, in beats.
public let stepLengths: [(name: String, beats: Double)] = [("1/4", 1), ("1/2", 2), ("1 BAR", 4), ("2 BARS", 8)]

/// The pattern and its editing cursor. Steps are nil for rests.
public struct Sequencer: Equatable {
    public static let maxSteps = 16, minSteps = 4, growBy = 4
    public private(set) var steps: [SeqStep?] = Array(repeating: nil, count: 8)
    public private(set) var cursor = 0
    public var stepLengthIdx = 2
    public var recording = false

    public init() {}

    public var length: Int { steps.count }
    public var stepBeats: Double { stepLengths[stepLengthIdx].beats }
    public var isEmpty: Bool { steps.allSatisfy { $0 == nil } }

    /// Writes a chord (or a rest) at the cursor and moves to the next step, wrapping at the end.
    public mutating func write(_ step: SeqStep?) {
        steps[cursor] = step
        cursor = (cursor + 1) % length
    }

    /// Turns the chord just written into a slash chord: in SLASH bass you hold the bass key first, which records it,
    /// then press the chord key, which replaces that step instead of taking a new one.
    public mutating func rewriteLast(_ step: SeqStep) {
        steps[(cursor + length - 1) % length] = step
    }

    /// Steps back and clears that step, like Backspace in text.
    public mutating func backspace() {
        cursor = (cursor + length - 1) % length
        steps[cursor] = nil
    }

    public mutating func moveCursor(_ delta: Int) { cursor = ((cursor + delta) % length + length) % length }

    /// Adds or removes `growBy` steps at the end (4…16). Removing drops those steps' chords.
    public mutating func resize(grow: Bool) {
        let n = min(Self.maxSteps, max(Self.minSteps, length + (grow ? Self.growBy : -Self.growBy)))
        if n > length { steps += Array(repeating: nil, count: n - length) } else { steps.removeLast(length - n) }
        cursor = min(cursor, n - 1)
    }

    public mutating func cycleStepLength(_ delta: Int) {
        stepLengthIdx = (stepLengthIdx + delta + stepLengths.count) % stepLengths.count
    }

    /// Clears every step and puts the cursor back at the start.
    public mutating func clear() { steps = Array(repeating: nil, count: length); cursor = 0 }
}

extension RSplexState {
    /// Notes for a stored step, voiced with the current settings. Use a dedicated state for playback so voice
    /// leading follows the sequence, not live playing.
    public mutating func render(step: SeqStep) -> Output? {
        releaseAll()
        if let b = step.slash { press(degree: b) }
        press(degree: step.degree)
        if let m = step.mod { press(mod: m) }
        defer { releaseAll() }
        return renderHeld()
    }

    /// Copies the sound settings (key, scale, octave, voicing, bass) from another state, keeping this one's voicing history.
    public mutating func takeSettings(from s: RSplexState) {
        key = s.key; scaleIdx = s.scaleIdx; inversion = s.inversion; bassMode = s.bassMode; voiceLeading = s.voiceLeading
        shiftOctave(s.octave - octave)
    }
}

/// The display name for a step, e.g. "Am7" or "F/C".
public func stepName(_ step: SeqStep, key: Int, scale: [Int]) -> String {
    let name = chord(degree: step.degree, key: key, scale: scale, mod: step.mod).name
    return step.slash.map { name + "/" + noteNames[(key + scale[$0]) % 12] } ?? name
}
