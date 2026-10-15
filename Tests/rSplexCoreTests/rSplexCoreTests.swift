import Testing
@testable import rSplexCore

let major = scales[0].steps

@Test func cMajorDiatonicChords() {
    let names = (0..<7).map { chord(degree: $0, key: 0, scale: major, mod: nil).name }
    #expect(names == ["C", "Dm", "Em", "F", "G", "Am", "Bdim"])
}

@Test func harmonicMinorThirdIsAugmented() {
    #expect(chord(degree: 2, key: 9, scale: scales[2].steps, mod: nil).name == "Caug")
}

@Test func modifiers() {
    func c(_ d: Int, _ m: Int) -> Chord { chord(degree: d, key: 0, scale: major, mod: m) }
    #expect(c(0, 0).iv == [0, 3, 7] && c(0, 0).name == "Cm")
    #expect(c(1, 0).iv == [0, 4, 7] && c(1, 0).name == "D")
    #expect(c(4, 1).name == "G7" && c(4, 1).iv == [0, 4, 7, 10])
    #expect(c(0, 2).name == "Cmaj7" && c(0, 2).iv == [0, 4, 7, 11])
    #expect(c(1, 2).name == "Dm7" && c(1, 2).iv == [0, 3, 7, 10])
    #expect(c(6, 2).name == "Bm7b5" && c(6, 2).iv == [0, 3, 6, 10])
    #expect(c(0, 3).name == "Cadd9" && c(0, 3).iv == [0, 4, 7, 14])
    #expect(c(0, 4).name == "Csus4")
    #expect(c(0, 5).name == "C6" && c(1, 5).name == "Dsus2")
    #expect(c(0, 6).name == "Cdim" && c(1, 6).name == "Ddim")
    #expect(c(0, 7).name == "Caug" && c(0, 8).name == "Csus2")
    #expect(c(0, 9).name == "C5" && c(0, 9).iv == [0, 7, 12])
}

@Test func inversions() {
    #expect(invert([60, 64, 67], 0) == [60, 64, 67])
    #expect(invert([60, 64, 67], 1) == [64, 67, 72])
    #expect(invert([60, 64, 67], 2) == [67, 72, 76])
    #expect(invert([60, 64, 67], 3) == [60, 64, 67])
}

@Test func voiceLeadingPicksClosestInversion() {
    // C -> F: smoothest is C-F-A (2nd inversion of F, dropped an octave).
    #expect(leadVoicing([65, 69, 72], from: [60, 64, 67]) == [60, 65, 69])
    #expect(leadVoicing([65, 69, 72], from: []) == [65, 69, 72])
}

@Test func basicPlayback() {
    var s = RSplexState()
    #expect(s.render() == nil)
    s.press(degree: 0)
    #expect(s.render()!.notes == [60, 64, 67])
    s.press(degree: 4)
    #expect(s.render()!.name == "G")
    s.release(degree: 4)
    #expect(s.render()!.name == "C")   // falls back to the still-held chord
    s.release(degree: 0)
    #expect(s.render() == nil)
}

@Test func heldModifierRevertsOnRelease() {
    var s = RSplexState()
    s.press(degree: 0); s.press(mod: 1)
    #expect(s.render()!.name == "C7")
    s.release(mod: 1)
    #expect(s.render()!.name == "C")
}

@Test func octaveShiftMovesByOctaveAndClamps() {
    var s = RSplexState()
    s.press(degree: 0)
    s.shiftOctave(1)
    #expect(s.render()!.notes == [72, 76, 79])
    s.shiftOctave(5)
    #expect(s.octave == 2)
    s.shiftOctave(-10)
    #expect(s.octave == -2)
    #expect(s.render()!.notes == [36, 40, 43])
}

@Test func octaveShiftWorksWithVoiceLeading() {
    var s = RSplexState()
    s.voiceLeading = true
    s.press(degree: 0)
    let before = s.render()!.notes
    s.shiftOctave(1)
    #expect(s.render()!.notes == before.map { $0 + 12 })
    s.shiftOctave(-1)
    #expect(s.render()!.notes == before)
}

@Test func keyChangesStayInOneRegister() {
    var s = RSplexState()
    s.press(degree: 0)
    s.shiftKey(5)   // F
    #expect(s.render()!.notes.first == 65)
    s.shiftKey(6)   // B -> sits just below middle C, not near the top
    #expect(s.render()!.notes.first == 59)
    s.shiftKey(1)   // wraps to C
    #expect(s.key == 0)
    s.shiftKey(-1)
    #expect(s.key == 11)
}

@Test func bassModes() {
    var s = RSplexState()
    s.press(degree: 0)
    s.cycleBass()   // ROOT
    #expect(s.render()!.notes == [60, 64, 67, 36])
    s.cycleBass()   // SLASH
    s.release(degree: 0)
    s.press(degree: 1); s.press(degree: 5)   // hold D, then Am
    let out = s.render()!
    #expect(out.name == "Am/D")
    #expect(out.notes == [69, 72, 76, 38])
    s.cycleBass()   // OFF
    #expect(s.render()!.notes.count == 3)
}

@Test func dimModifierDiminishesAndTogglesDimToMinor() {
    func c(_ d: Int) -> Chord { chord(degree: d, key: 0, scale: major, mod: 6) }
    #expect(c(0).name == "Cdim" && c(0).iv == [0, 3, 6])    // major -> dim
    #expect(c(1).name == "Ddim" && c(1).iv == [0, 3, 6])    // minor -> dim
    #expect(c(6).name == "Bm" && c(6).iv == [0, 3, 7])      // dim -> minor
    #expect(chord(degree: 2, key: 9, scale: scales[2].steps, mod: 6).name == "Cdim")   // aug -> dim
}

@Test func voiceLeadingDoesNotDriftOverRepeatedProgressions() {
    for prog in [[0, 1, 2, 3, 4], [0, 3, 4, 5], [0, 5, 3, 4], [4, 3, 2, 1, 0], [0, 4, 5, 2, 3, 0, 3, 4]] {
        var s = RSplexState()
        s.voiceLeading = true
        var loops: [[[Int]]] = []
        for _ in 0..<6 {
            var loop: [[Int]] = []
            for d in prog { s.press(degree: d); loop.append(s.render()!.notes); s.release(degree: d) }
            loops.append(loop)
        }
        // Settles after the first pass and then repeats exactly.
        #expect(loops[2...].allSatisfy { $0 == loops[1] }, "progression \(prog)")
        // Stays within about an octave of the chords' home position (roots at 60–71).
        for chordNotes in loops.joined() { #expect(chordNotes.allSatisfy { (52...84).contains($0) }, "\(chordNotes)") }
    }
}

@Test func heldChordKeepsItsVoicingWhenAnEarlierKeyIsReleased() {
    // Every pair of chords, in every key: hold A, hold B, release A — B must not re-voice.
    for key in 0..<12 {
        for a in 0..<7 {
            for b in 0..<7 where b != a {
                var s = RSplexState()
                s.voiceLeading = true
                s.shiftKey(key)
                s.press(degree: a); _ = s.render()
                s.press(degree: b)
                let before = s.render()!.notes
                s.release(degree: a)
                #expect(s.render()!.notes == before, "key \(key): \(a) then \(b)")
            }
        }
    }
}

@Test func shiftTabCyclesScalesBackwards() {
    var s = RSplexState()
    s.previousScale()
    #expect(s.scaleIdx == scales.count - 1)
    s.nextScale()
    #expect(s.scaleIdx == 0)
}

@Test func bassStaysAudibleAtLowOctaves() {
    var s = RSplexState()
    s.cycleBass()   // ROOT
    s.shiftKey(6)   // F#, the lowest-sitting key
    s.shiftOctave(-2)
    s.press(degree: 0)
    let notes = s.render()!.notes
    #expect(notes.last! >= lowestBass)
    #expect(notes.last! <= notes.first!)  // never above the chord (doubles the root at the very bottom)
    s.shiftOctave(4)
    #expect(s.render()!.notes.last! == s.rootMidi(degree: 0) - 24)   // untouched when already audible
}

@Test func holdingFourSecondsLocks() {
    var s = RSplexState()
    s.press(degree: 0)
    _ = s.render(now: 10)
    #expect(s.lockProgress(now: 12) == 0.5)
    _ = s.render(now: 13.9)
    #expect(s.lock == nil)
    _ = s.render(now: 14)
    #expect(s.lock?.degree == 0)
    s.release(degree: 0)
    #expect(s.render(now: 15)?.name == "C")   // keeps sounding with no keys held
    s.releaseAll()                              // window losing focus
    #expect(s.render(now: 16)?.name == "C")
}

@Test func lockIncludesHeldModifier() {
    var s = RSplexState()
    s.press(degree: 4); s.press(mod: 1)
    _ = s.render(now: 0)
    _ = s.render(now: 4)
    #expect(s.lock?.mod == 1)
    s.release(mod: 1); s.release(degree: 4)
    #expect(s.render(now: 5)?.name == "G7")
}

@Test func changingTheChordRestartsTheLockTimer() {
    var s = RSplexState()
    s.press(degree: 0)
    _ = s.render(now: 0)
    s.press(mod: 1)
    _ = s.render(now: 3)          // C7 starts sounding at 3 s
    _ = s.render(now: 6)
    #expect(s.lock == nil)
    _ = s.render(now: 7)
    #expect(s.lock?.output.name == "C7")
}

@Test func otherKeyBreaksLockAndPlays() {
    var s = RSplexState()
    s.press(degree: 0); _ = s.render(now: 0); _ = s.render(now: 4); s.release(degree: 0)
    #expect(s.breakLock(pressingDegree: 3) == 0)
    s.press(degree: 3)
    #expect(s.render(now: 5)?.name == "F")
    s.release(degree: 3)
    #expect(s.render(now: 6) == nil)
}

@Test func nonChordKeyBreaksLock() {
    var s = RSplexState()
    s.press(degree: 0); _ = s.render(now: 0); _ = s.render(now: 4); s.release(degree: 0)
    #expect(s.breakLock() == 0)
    s.shiftOctave(1)
    #expect(s.render(now: 5) == nil)
    #expect(s.breakLock() == nil)   // nothing left to break
}

@Test func sameKeyBreaksLockReplaysAndCannotRelockUntilReleased() {
    var s = RSplexState()
    s.press(degree: 0); _ = s.render(now: 0); _ = s.render(now: 4); s.release(degree: 0)
    s.breakLock(pressingDegree: 0)
    s.press(degree: 0)
    #expect(s.render(now: 5)?.name == "C")
    #expect(s.lockProgress(now: 5) == nil)
    _ = s.render(now: 20)
    #expect(s.lock == nil)                      // held 15 s, still not locked
    s.release(degree: 0)
    #expect(s.render(now: 21) == nil)           // stops on release
    s.press(degree: 0)                          // a fresh press can lock again
    _ = s.render(now: 22); _ = s.render(now: 26)
    #expect(s.lock != nil)
}

@Test func lockCanBeTurnedOff() {
    var s = RSplexState()
    s.lockEnabled = false
    s.press(degree: 0)
    _ = s.render(now: 0); _ = s.render(now: 60)
    #expect(s.lock == nil)
    #expect(s.lockProgress(now: 60) == nil)
    s.release(degree: 0)
    #expect(s.render(now: 61) == nil)
    s.lockEnabled = true             // re-enabled: works again on a fresh hold
    s.press(degree: 0)
    _ = s.render(now: 70); _ = s.render(now: 74)
    #expect(s.lock?.mod == nil)
}
