import Testing
@testable import rSplexCore

let sr = 48_000.0
let classic = envelopePresets[0].adsr

/// Renders `seconds` of audio and returns the peak absolute sample.
@discardableResult
func run(_ e: inout VoiceEngine, seconds: Double) -> Float {
    let n = Int(seconds * sr)
    var buf = [Float](repeating: 0, count: n)
    buf.withUnsafeMutableBufferPointer { e.render(frames: n, into: $0.baseAddress!) }
    return buf.map(abs).max() ?? 0
}

@Test func attackReachesFullLevelOnTime() {
    var e = VoiceEngine(sampleRate: sr)
    e.handle(.noteOn(60, ADSR(0.1, 0, 1, 0.3)))
    run(&e, seconds: 0.05)
    #expect(abs(e.voice(for: 60)!.level - 0.5) < 0.001)
    run(&e, seconds: 0.051)
    #expect(e.voice(for: 60)!.level == 1)
    #expect(e.voice(for: 60)!.stage == .sustain)
}

@Test func decayFallsToSustainWhileHeld() {
    var e = VoiceEngine(sampleRate: sr)
    e.handle(.noteOn(60, ADSR(0, 0.2, 0.5, 0.3)))
    run(&e, seconds: 0.3)
    #expect(e.voice(for: 60)!.level == 0.5)
    #expect(e.voice(for: 60)!.stage == .sustain)
}

@Test func pluckDiesOutEvenWhileHeld() {
    var e = VoiceEngine(sampleRate: sr)
    e.handle(.noteOn(60, envelopePresets.first { $0.name == "PLUCK" }!.adsr))
    run(&e, seconds: 0.1)
    #expect(e.activeNotes.isEmpty)
    #expect(run(&e, seconds: 0.05) < 0.001)
}

@Test func releaseFadesToSilenceAndFreesTheVoice() {
    var e = VoiceEngine(sampleRate: sr)
    e.handle(.noteOn(60, classic))
    run(&e, seconds: 0.1)
    e.handle(.noteOff(60))
    run(&e, seconds: 0.15)
    #expect(abs(e.voice(for: 60)!.level - 0.5) < 0.01)   // halfway through the 0.3 s release
    run(&e, seconds: 0.16)
    #expect(e.activeNotes.isEmpty)
    #expect(run(&e, seconds: 0.05) < 0.001)
}

@Test func releaseDuringAttackStartsFromCurrentLevel() {
    var e = VoiceEngine(sampleRate: sr)
    e.handle(.noteOn(60, ADSR(1, 0, 1, 0.1)))
    run(&e, seconds: 0.25)
    e.handle(.noteOff(60))
    run(&e, seconds: 0.05)
    #expect(abs(e.voice(for: 60)!.level - 0.125) < 0.01)   // 0.25 → 0 over 0.1 s
}

@Test func chordChangeKeepsSharedNotesRinging() {
    let (off, on) = chordDiff(from: [60, 64, 67], to: [60, 65, 69])
    #expect(off == [64, 67] && on == [65, 69])
    var e = VoiceEngine(sampleRate: sr)
    for n in [60, 64, 67] { e.handle(.noteOn(n, classic)) }
    run(&e, seconds: 0.1)
    for n in off { e.handle(.noteOff(n)) }
    for n in on { e.handle(.noteOn(n, classic)) }
    run(&e, seconds: 0.002)
    #expect(e.voice(for: 60)!.stage == .sustain)   // untouched
    #expect(e.voice(for: 64)!.stage == .release)
    #expect(e.voice(for: 65)!.stage == .attack)
}

@Test func retriggeringARingingNoteReusesItsVoice() {
    var e = VoiceEngine(sampleRate: sr, voiceCount: 4)
    e.handle(.noteOn(60, classic)); run(&e, seconds: 0.1)
    e.handle(.noteOff(60)); run(&e, seconds: 0.05)
    e.handle(.noteOn(60, classic))
    #expect(e.voices.filter { $0.stage != .idle }.count == 1)
    #expect(e.voice(for: 60)!.stage == .attack)
    #expect(e.voice(for: 60)!.level > 0.5)   // picks up from where the release was, no click
}

@Test func voiceStealingPrefersQuietestReleasingThenOldest() {
    var e = VoiceEngine(sampleRate: sr, voiceCount: 3)
    for n in [60, 62, 64] { e.handle(.noteOn(n, ADSR(0, 0, 1, 1))); run(&e, seconds: 0.01) }
    e.handle(.noteOff(62)); run(&e, seconds: 0.5)
    e.handle(.noteOn(70, classic))
    #expect(e.activeNotes == [60, 64, 70])        // took the releasing voice
    e.handle(.noteOn(72, classic))
    #expect(e.activeNotes == [64, 70, 72])        // nothing releasing: took the oldest (60)
}

@Test func beatClockFollowsBPM() {
    var e = VoiceEngine(sampleRate: sr)
    run(&e, seconds: 1)
    #expect(abs(e.beats - 2) < 1e-6)              // 120 BPM default
    e.handle(.setBPM(60))
    run(&e, seconds: 1)
    #expect(abs(e.beats - 3) < 1e-6)
    e.handle(.setBPM(1000))
    #expect(e.bpm == 300)
}

@Test func matchesOriginalLoudnessAndBigChordsDontClip() {
    // Peaks of the original engine over 0.5 s, measured from its code before the rewrite.
    var triad = VoiceEngine(sampleRate: sr)
    for n in [60, 64, 67] { triad.handle(.noteOn(n, classic)) }
    #expect(abs(run(&triad, seconds: 0.5) - 0.08818) < 0.0005)
    var seventh = VoiceEngine(sampleRate: sr)
    for n in [60, 64, 67, 71] { seventh.handle(.noteOn(n, classic, gain: 3.0 / 4)) }
    #expect(abs(run(&seventh, seconds: 0.5) - 0.08685) < 0.0005)
    var big = VoiceEngine(sampleRate: sr)
    for n in 40..<56 { big.handle(.noteOn(n, classic)) }
    #expect(run(&big, seconds: 0.5) <= 1)
    #expect(VoiceEngine.softClip(0.5) == 0.5)
}

@Test func tapTempo() {
    var t = TapTempo()
    #expect(t.tap(at: 0) == nil)
    #expect(t.tap(at: 0.5) == nil)
    #expect(t.tap(at: 1.0) == 120)                 // needs three taps
    #expect(t.tap(at: 1.5) == 120)
    #expect(t.tap(at: 10) == nil)                  // long gap starts over
    _ = t.tap(at: 10.1); #expect(t.tap(at: 10.2) == 300)   // clamped
}
