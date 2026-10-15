public let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
public let scales: [(name: String, steps: [Int])] = [
    ("Major", [0, 2, 4, 5, 7, 9, 11]), ("Natural Minor", [0, 2, 3, 5, 7, 8, 10]),
    ("Harmonic Minor", [0, 2, 3, 5, 7, 8, 11]), ("Melodic Minor", [0, 2, 3, 5, 7, 9, 11]),
    ("Dorian", [0, 2, 3, 5, 7, 9, 10]), ("Mixolydian", [0, 2, 4, 5, 7, 9, 10]),
    ("Lydian", [0, 2, 4, 6, 7, 9, 11])]
/// Number-row modifiers, held while a chord key is down.
public let modLabels = ["M/m flip", "7", "maj7/m7", "add9", "sus4", "6/sus2", "m/dim", "aug", "sus2", "5"]
public let bassModes = ["OFF", "ROOT", "SLASH"]
public let octaveRange = -1...2

public struct Chord: Equatable {
    /// Semitones above C of the key's tonic octave (may exceed 11).
    public var root: Int
    public var iv: [Int]
    public var name: String
}

/// Diatonic chord for a scale degree (stacked thirds), with an optional modifier applied.
public func chord(degree d: Int, key: Int, scale: [Int], mod: Int?) -> Chord {
    func s(_ i: Int) -> Int { scale[i % 7] + 12 * (i / 7) }
    let third = s(d + 2) - s(d), fifth = s(d + 4) - s(d)
    let major = third == 4
    var iv = [0, third, fifth]
    var suffix: String
    switch (third, fifth) {
    case (4, 7): suffix = ""
    case (3, 7): suffix = "m"
    case (3, 6): suffix = "dim"
    case (4, 8): suffix = "aug"
    default: suffix = "?"
    }
    if let m = mod {
        switch m {
        case 0: iv = major ? [0, 3, 7] : [0, 4, 7]; suffix = major ? "m" : ""
        case 1: iv = [0, 4, 7, 10]; suffix = "7"
        case 2:
            if major { iv = [0, 4, 7, 11]; suffix = "maj7" }
            else if fifth == 6 { iv = [0, 3, 6, 10]; suffix = "m7b5" }
            else { iv = [0, 3, 7, 10]; suffix = "m7" }
        case 3: iv.append(14); suffix += "add9"
        case 4: iv = [0, 5, 7]; suffix = "sus4"
        case 5: if major { iv = [0, 4, 7, 9]; suffix = "6" } else { iv = [0, 2, 7]; suffix = "sus2" }
        case 6:
            // Toggles between minor and diminished; a major chord goes to minor.
            if third == 3 && fifth == 7 { iv = [0, 3, 6]; suffix = "dim" } else { iv = [0, 3, 7]; suffix = "m" }
        case 7: iv = [0, 4, 8]; suffix = "aug"
        case 8: iv = [0, 2, 7]; suffix = "sus2"
        default: iv = [0, 7, 12]; suffix = "5"
        }
    }
    return Chord(root: key + scale[d], iv: iv, name: noteNames[(key + scale[d]) % 12] + suffix)
}

/// Move the lowest note up an octave, k times.
public func invert(_ notes: [Int], _ k: Int) -> [Int] {
    var n = notes
    for _ in 0..<(k % n.count) { n.append(n.removeFirst() + 12) }
    return n
}

/// Inversion/octave of `notes` closest to `prev`, measured note-to-nearest-note both ways.
/// Each semitone the voicing's average pitch strays from `notes` (the chord's home position) costs `registerPull`,
/// so steps that are each smoothest can't ratchet the register up or down over a progression.
public let registerPull = 2.0

public func leadVoicing(_ notes: [Int], from prev: [Int]) -> [Int] {
    guard !prev.isEmpty else { return notes }
    func mean(_ a: [Int]) -> Double { Double(a.reduce(0, +)) / Double(a.count) }
    let home = mean(notes)
    func cost(_ a: [Int]) -> Double {
        let motion = a.map { x in prev.map { abs($0 - x) }.min()! }.reduce(0, +)
            + prev.map { x in a.map { abs($0 - x) }.min()! }.reduce(0, +)
        return Double(motion) + registerPull * abs(mean(a) - home)
    }
    var best = notes, bestCost = Double.infinity
    for shift in [0, -12, 12] {
        for k in 0..<notes.count {
            let cand = invert(notes, k).map { $0 + shift }
            let c = cost(cand)
            if c < bestCost { best = cand; bestCost = c }
        }
    }
    return best
}

/// All player state; the UI forwards key events here and plays whatever `render()` returns.
public struct RSplexState {
    public var key = 0, scaleIdx = 0, inversion = 0, bassMode = 0
    public var voiceLeading = false
    public private(set) var octave = 0
    public private(set) var held: [Int] = []   // scale degrees, in press order
    public private(set) var mods: [Int] = []   // modifiers, in press order
    private var lastVoicing: [Int] = []

    public init() {}

    public var scale: [Int] { scales[scaleIdx].steps }

    public mutating func press(degree d: Int) { held.removeAll { $0 == d }; held.append(d) }
    public mutating func release(degree d: Int) { held.removeAll { $0 == d } }
    public mutating func press(mod m: Int) { mods.removeAll { $0 == m }; mods.append(m) }
    public mutating func release(mod m: Int) { mods.removeAll { $0 == m } }
    public mutating func releaseAll() { held.removeAll(); mods.removeAll() }
    public mutating func shiftKey(_ delta: Int) { key = ((key + delta) % 12 + 12) % 12 }
    public mutating func nextScale() { scaleIdx = (scaleIdx + 1) % scales.count }
    public mutating func cycleInversion() { inversion = (inversion + 1) % 3 }
    public mutating func cycleBass() { bassMode = (bassMode + 1) % bassModes.count }

    public mutating func shiftOctave(_ delta: Int) {
        let new = min(octaveRange.upperBound, max(octaveRange.lowerBound, octave + delta))
        // Move the voice-leading reference too, or it would pull the next chord back down.
        lastVoicing = lastVoicing.map { $0 + 12 * (new - octave) }
        octave = new
    }

    /// MIDI note of a degree's root. Keys above F# sit below middle C so every key stays in one register.
    public func rootMidi(degree d: Int) -> Int {
        60 + (key >= 6 ? key - 12 : key) + scale[d] + 12 * octave
    }

    /// Notes to sound (chord voicing first, then any bass note) and the chord's display name; nil when nothing is held.
    public mutating func render() -> (notes: [Int], name: String)? {
        guard let deg = held.last else { return nil }
        let c = chord(degree: deg, key: key, scale: scale, mod: mods.last)
        let root = rootMidi(degree: deg)
        let base = c.iv.map { root + $0 }
        let voicing = voiceLeading ? leadVoicing(base, from: lastVoicing) : invert(base, inversion)
        lastVoicing = voicing
        var notes = voicing, name = c.name
        if bassMode == 1 || (bassMode == 2 && held.count < 2) {
            notes.append(root - 24)
        } else if bassMode == 2 {
            notes.append(rootMidi(degree: held[0]) - 24)
            name += "/" + noteNames[(key + scale[held[0]]) % 12]
        }
        return (notes, name)
    }
}
