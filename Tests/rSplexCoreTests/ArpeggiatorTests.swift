import Testing
@testable import rSplexCore

func steps(_ p: ArpPattern, _ n: Int, _ k: Int) -> [Int] { (0..<k).map { p.index(step: $0, count: n) } }

@Test func directionalPatterns() {
    #expect(steps(.up, 3, 6) == [0, 1, 2, 0, 1, 2])
    #expect(steps(.down, 3, 6) == [2, 1, 0, 2, 1, 0])
    #expect(steps(.upDown, 4, 8) == [0, 1, 2, 3, 2, 1, 0, 1])
    #expect(steps(.downUp, 4, 8) == [3, 2, 1, 0, 1, 2, 3, 2])
    #expect(steps(.upDown, 2, 4) == [0, 1, 0, 1])
}

@Test func fingerpickIsLowHighMiddleHigh() {
    #expect(steps(.fingerpick, 3, 8) == [0, 2, 1, 2, 0, 2, 1, 2])
    #expect(steps(.fingerpick, 4, 6) == [0, 3, 1, 3, 2, 3])
}

@Test func singleNoteAlwaysIndexZero() {
    for p in ArpPattern.allCases { #expect(steps(p, 1, 4) == [0, 0, 0, 0]) }
}

@Test func swingSplitsPairsTwoToOne() {
    #expect(ArpRate.swing8.length(ofTick: 0) == 2.0 / 3)
    #expect(abs(ArpRate.swing8.length(ofTick: 1) - 1.0 / 3) < 1e-12)
    #expect(ArpRate.eighth.length(ofTick: 0) == 0.5)
    #expect(ArpRate.eighth.length(ofTick: 1) == 0.5)
    #expect(abs(ArpRate.sixteenthTriplet.length(ofTick: 0) * 3 - 0.5) < 1e-12)
}

@Test func arpNotesAreSortedAndCapped() {
    let n = ArpNotes([67, 60, 64])
    #expect(n.count == 3 && n[0] == 60 && n[1] == 64 && n[2] == 67)
    #expect(ArpNotes(0..<40).count == ArpNotes.capacity)
}

func arp(_ notes: [Int], _ p: ArpPattern = .up, _ r: ArpRate = .eighth) -> Arp {
    Arp(notes: ArpNotes(notes), pattern: p, rate: r, adsr: classic)
}

@Test func engineStepsOnTheBeatClock() {
    // 120 BPM, 1/8: a new note every 0.25 s, each gated off after half its step.
    var e = VoiceEngine(sampleRate: sr)
    e.handle(.setArp(arp([60, 64, 67])))
    run(&e, seconds: 0.01)
    #expect(e.arpNote == 60)                   // first note right away
    run(&e, seconds: 0.2)
    #expect(e.arpNote == nil)                  // gated off at 0.125 s
    run(&e, seconds: 0.05)
    #expect(e.arpNote == 64)                   // 0.26 s
    run(&e, seconds: 0.25)
    #expect(e.arpNote == 67)
    run(&e, seconds: 0.25)
    #expect(e.arpNote == 60)                   // wrapped
}

@Test func newChordRestartsPatternButKeepsTiming() {
    var e = VoiceEngine(sampleRate: sr)
    e.handle(.setArp(arp([60, 64, 67])))
    run(&e, seconds: 0.3)                      // second note is playing
    e.handle(.setArp(arp([62, 65, 69])))
    run(&e, seconds: 0.05)
    #expect(e.arpNote == 64)                   // nothing retriggered mid-step
    run(&e, seconds: 0.16)
    #expect(e.arpNote == 62)                   // 0.5 s: next tick, from the start of the new chord
}

@Test func stoppingLetsTheLastNoteGateOut() {
    var e = VoiceEngine(sampleRate: sr)
    e.handle(.setArp(arp([60, 64])))
    run(&e, seconds: 0.05)
    e.handle(.setArp(nil))
    #expect(e.arpNote == 60)
    run(&e, seconds: 0.1)
    #expect(e.arpNote == nil)
    run(&e, seconds: 0.5)
    #expect(e.activeNotes.isEmpty)
}

@Test func randomNeverRepeatsANote() {
    var e = VoiceEngine(sampleRate: sr)
    e.handle(.setArp(arp([60, 64, 67], .random, .thirtySecond)))
    var played: [Int] = []
    for _ in 0..<200 {
        run(&e, seconds: 0.0625 / 4)               // a quarter of a 1/32 step
        if let n = e.arpNote, played.last != n { played.append(n) }
    }
    #expect(Set(played) == [60, 64, 67])
    #expect(played.count > 30)
}
