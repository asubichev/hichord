import Testing
@testable import rSplexCore

let c = SeqStep(degree: 0), f = SeqStep(degree: 3), g = SeqStep(degree: 4)

@Test func insertGoesAtTheCursorAndShiftsRight() {
    var s = Sequencer()
    s.insert(c); s.insert(g)
    s.moveCursor(-1)                          // between C and G
    #expect(s.insert(f) == 1)
    #expect(s.steps == [c, f, g] && s.cursor == 2)
}

@Test func insertStopsWhenFull() {
    var s = Sequencer()
    for _ in 0..<Sequencer.maxSteps { s.insert(c) }
    #expect(s.insert(g) == nil && s.count == Sequencer.maxSteps)
}

@Test func deleteRemovesTheStepBeforeTheCursor() {
    var s = Sequencer()
    s.insert(c); s.insert(f); s.insert(g)
    s.moveCursor(-1)                          // between F and G
    s.deleteBeforeCursor()
    #expect(s.steps == [c, g] && s.cursor == 1)
    s.deleteBeforeCursor(); s.deleteBeforeCursor()
    #expect(s.steps == [g] && s.cursor == 0)  // nothing before the cursor: no-op
}

@Test func cursorStaysWithinTheGaps() {
    var s = Sequencer()
    s.insert(c); s.insert(f)
    s.moveCursor(5)
    #expect(s.cursor == 2)
    s.moveCursor(-5)
    #expect(s.cursor == 0)
}

@Test func rewriteReplacesWithoutMovingTheCursor() {
    var s = Sequencer()
    let i = s.insert(g)!
    s.rewrite(at: i, SeqStep(degree: 0, slash: 4))
    #expect(s.steps == [SeqStep(degree: 0, slash: 4)] && s.cursor == 1)
}

@Test func stepLengthStopsAtTheEnds() {
    var s = Sequencer()
    s.changeStepLength(-5)
    #expect(s.stepLengthIdx == 0)
    s.changeStepLength(9)
    #expect(s.stepLengthIdx == stepLengths.count - 1)
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
