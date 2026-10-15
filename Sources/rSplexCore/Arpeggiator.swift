import Foundation

public enum ArpPattern: Int, CaseIterable {
    case up, down, upDown, downUp, random, fingerpick

    public var name: String { ["UP", "DOWN", "UP/DN", "DN/UP", "RANDOM", "FINGER"][rawValue] }

    /// Which note (index into the sorted notes) plays on pattern step `k`. Random is handled by the engine.
    /// Up/Down and Down/Up don't repeat the end notes; Fingerpick is low, high, middle, high (p-a-m-a), with
    /// bigger chords walking the inner notes upward between returns to the top.
    public func index(step k: Int, count n: Int) -> Int {
        guard n > 1 else { return 0 }
        switch self {
        case .up, .random: return k % n
        case .down: return n - 1 - k % n
        case .upDown, .downUp:
            let c = 2 * n - 2, i = k % c
            let up = i < n ? i : c - i
            return self == .upDown ? up : n - 1 - up
        case .fingerpick:
            let i = k % (2 * (n - 1))
            return i == 0 ? 0 : i % 2 == 1 ? n - 1 : i / 2
        }
    }
}

public enum ArpRate: Int, CaseIterable {
    case whole, half, quarter, eighth, sixteenth, sixteenthTriplet, thirtySecond, swing8, swing16

    public static let defaultRate = ArpRate.eighth
    public var name: String { ["1/1", "1/2", "1/4", "1/8", "1/16", "1/16T", "1/32", "SW 1/8", "SW 1/16"][rawValue] }

    /// Step length in beats (quarter notes), before swing.
    public var beats: Double { [4, 2, 1, 0.5, 0.25, 1.0 / 6, 0.125, 0.5, 0.25][rawValue] }

    /// Swing gives each pair of steps a long-short (2:1, triplet feel) split.
    public var swing: Double { self == .swing8 || self == .swing16 ? 2.0 / 3 : 0.5 }

    /// Length of tick `t` in beats; ticks alternate long/short when swung.
    public func length(ofTick t: Int) -> Double { 2 * beats * (t % 2 == 0 ? swing : 1 - swing) }
}

/// Up to 16 sorted notes stored inline, so passing them to the audio thread never allocates.
public struct ArpNotes: Equatable {
    public static let capacity = 16
    private var storage = SIMD16<Int32>()
    public private(set) var count = 0

    public init<S: Sequence>(_ notes: S) where S.Element == Int {
        for n in notes.sorted().prefix(Self.capacity) { storage[count] = Int32(n); count += 1 }
    }

    public subscript(i: Int) -> Int { Int(storage[i]) }
    public var isEmpty: Bool { count == 0 }
}

/// Everything the engine needs to run an arpeggio.
public struct Arp: Equatable {
    public var notes: ArpNotes
    public var pattern: ArpPattern
    public var rate: ArpRate
    public var adsr: ADSR
    public var gain: Double

    /// Each note sounds for this share of its step; the envelope's release rings past that.
    public static let gate = 0.5

    public init(notes: ArpNotes, pattern: ArpPattern, rate: ArpRate, adsr: ADSR, gain: Double = 1.5) {
        self.notes = notes; self.pattern = pattern; self.rate = rate; self.adsr = adsr; self.gain = gain
    }
}

/// How the arp layers with the held chord. CHORD+ARP plays the arp an octave up so it sits above the chord.
public let arpModes = ["OFF", "ARP", "CHORD+ARP"]
