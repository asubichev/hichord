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
    public static let maxSteps = 8, minSteps = 4, growBy = 4
    public private(set) var steps: [SeqStep?] = Array(repeating: nil, count: 8)
    public private(set) var cursor = 0
    public var stepLengthIdx = 2

    public init() {}

    public var length: Int { steps.count }
    public var stepBeats: Double { stepLengths[stepLengthIdx].beats }
    public var isEmpty: Bool { steps.allSatisfy { $0 == nil } }

    /// Writes a chord (or a rest) at the cursor and moves to the next step, wrapping at the end. Returns the step written.
    @discardableResult
    public mutating func write(_ step: SeqStep?) -> Int {
        let i = cursor
        steps[i] = step
        cursor = (cursor + 1) % length
        return i
    }

    /// Replaces a step without moving the cursor, e.g. as the chord being recorded changes while it's held.
    public mutating func rewrite(at i: Int, _ step: SeqStep) {
        guard steps.indices.contains(i) else { return }
        steps[i] = step
    }

    /// Clears the step at the cursor to a rest and moves left one (stopping at the first step). Other steps stay put.
    public mutating func deleteAtCursor() {
        steps[cursor] = nil
        cursor = max(0, cursor - 1)
    }

    public mutating func moveCursor(_ delta: Int) { cursor = ((cursor + delta) % length + length) % length }

    /// Adds or removes `growBy` steps at the end (4…16). Removing drops those steps' chords.
    public mutating func resize(grow: Bool) {
        let n = min(Self.maxSteps, max(Self.minSteps, length + (grow ? Self.growBy : -Self.growBy)))
        if n > length { steps += Array(repeating: nil, count: n - length) } else { steps.removeLast(length - n) }
        cursor = min(cursor, n - 1)
    }

    /// Moves through `stepLengths` (shorter → longer), stopping at either end.
    public mutating func changeStepLength(_ delta: Int) {
        stepLengthIdx = min(stepLengths.count - 1, max(0, stepLengthIdx + delta))
    }
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
