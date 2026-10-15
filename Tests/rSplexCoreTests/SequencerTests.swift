import Testing
@testable import rSplexCore

@Test func writingAdvancesAndWraps() {
    var s = Sequencer()
    for d in 0..<8 { s.write(SeqStep(degree: d % 7)) }
    #expect(s.cursor == 0)
    s.write(nil)
    #expect(s.steps[0] == nil && s.steps[1] == SeqStep(degree: 1) && s.cursor == 1)
}

@Test func rewriteReplacesWithoutMovingTheCursor() {
    var s = Sequencer()
    let i = s.write(SeqStep(degree: 4))
    s.rewrite(at: i, SeqStep(degree: 0, slash: 4))
    #expect(s.steps[0] == SeqStep(degree: 0, slash: 4) && s.cursor == 1)
}

@Test func deleteClearsCurrentStepAndMovesLeft() {
    var s = Sequencer()
    s.write(SeqStep(degree: 0)); s.write(SeqStep(degree: 3)); s.write(SeqStep(degree: 4))
    s.moveCursor(-1)                          // on step 3 (degree 4)
    s.deleteAtCursor()
    #expect(s.steps[2] == nil && s.steps[1] == SeqStep(degree: 3) && s.cursor == 1)
    s.deleteAtCursor(); s.deleteAtCursor()
    #expect(s.cursor == 0 && s.isEmpty)       // stops at the first step
}

@Test func stepLengthStopsAtTheEnds() {
    var s = Sequencer()
    s.changeStepLength(-5)
    #expect(s.stepLengthIdx == 0)
    s.changeStepLength(9)
    #expect(s.stepLengthIdx == stepLengths.count - 1)
}

@Test func resizeByFourWithinLimits() {
    var s = Sequencer()
    s.resize(grow: true)
    #expect(s.length == 8)                    // 8 is the most
    s.moveCursor(-1)
    #expect(s.cursor == 7)
    s.resize(grow: false); s.resize(grow: false)
    #expect(s.length == 4 && s.cursor == 3)
}

@Test func stepRendersWithLiveSettings() {
    var live = RSplexState(), v = RSplexState()
    live.shiftKey(2)                           // D major
    v.takeSettings(from: live)
    #expect(v.render(step: SeqStep(degree: 0))?.name == "D")
    #expect(v.render(step: SeqStep(degree: 1, mod: 1))?.name == stepName(SeqStep(degree: 1, mod: 1), key: 2, scale: live.scale))
    #expect(v.held.isEmpty && v.mods.isEmpty)  // rendering leaves no keys held
    v.bassMode = 2
    #expect(v.render(step: SeqStep(degree: 0, slash: 4))?.name == "D/A")
}

@Test func scheduledEventsPlayOnTheirBeat() {
    var e = VoiceEngine(sampleRate: sr)       // 120 BPM: 1 beat = 0.5 s
    e.schedule(TimedEvent(1, .noteOn(60, classic, layer: sequencerLayer)))
    e.schedule(TimedEvent(0.5, .noteOn(64, classic)))
    run(&e, seconds: 0.24)
    #expect(e.activeNotes.isEmpty)
    run(&e, seconds: 0.02)
    #expect(e.activeNotes == [64])
    run(&e, seconds: 0.25)
    #expect(e.activeNotes(layer: sequencerLayer) == [60])
}

@Test func layersDontCutEachOtherOff() {
    var e = VoiceEngine(sampleRate: sr)
    e.handle(.noteOn(60, classic))
    e.handle(.noteOn(60, classic, layer: sequencerLayer))
    e.handle(.noteOff(60, layer: sequencerLayer))
    run(&e, seconds: 0.5)
    #expect(e.voice(for: 60)?.stage == .sustain)
    #expect(e.voice(for: 60, layer: sequencerLayer) == nil)
}

@Test func cancelDropsOnlyThatLayer() {
    var e = VoiceEngine(sampleRate: sr)
    e.schedule(TimedEvent(1, .noteOn(60, classic, layer: sequencerLayer)))
    e.schedule(TimedEvent(1, .noteOn(64, classic)))
    e.handle(.cancelScheduled(layer: sequencerLayer))
    #expect(e.scheduledCount == 1)
}
