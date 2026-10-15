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
    #expect(c(0, 6).name == "Cm" && c(1, 6).name == "Ddim")
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
    #expect(s.octave == -1)
    #expect(s.render()!.notes == [48, 52, 55])
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

@Test func minorDimToggleSwitchesBothWays() {
    func c(_ d: Int) -> Chord { chord(degree: d, key: 0, scale: major, mod: 6) }
    #expect(c(0).name == "Cm" && c(0).iv == [0, 3, 7])      // major -> minor
    #expect(c(1).name == "Ddim" && c(1).iv == [0, 3, 6])    // minor -> dim
    #expect(c(6).name == "Bm" && c(6).iv == [0, 3, 7])      // dim -> minor
}
