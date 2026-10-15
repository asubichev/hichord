# Roadmap

Scope rule: every feature is intentional, specified before it's built, tested where it has logic, and played before
it merges. Anything that doesn't feel right gets cut, not shipped. Each feature gets an issue (with what "done" means),
a branch, and a PR. Every merge to `main` publishes a release, so features stay on their branch until they're finished.

Current release: **v1.0** — 7 diatonic chord keys, held number-row modifiers, key/scale/octave, inversions, voice
leading, bass (OFF/ROOT/SLASH).

## v1.1 — Polish + foundation

The arpeggiator and sequencer need two things the app doesn't have yet: a tempo clock, and notes that start and stop
independently (today the whole chord shares one envelope). This release builds both, plus small fixes.

- **Octave range −2…+2** (was −1…+2).
- **Shift+Tab** cycles scales backwards.
- **Hold-to-lock** (new idea, not a HiChord feature — HiChord's "chord lock" permanently rebinds a button, which is
  different). See spec below.
- **Engine rewrite:** per-note voices with ADSR. Adds HiChord's envelope presets (LONG, SHORT, SWELL, PLUCK, TOUCH,
  SUSTAIN) almost for free.
- **Transport:** BPM (40–300) and tap tempo, clocked in the audio thread so timing is sample-accurate.
- Tests for the clock, note on/off scheduling, and the lock state machine.

### Hold-to-lock spec

- Holding a chord key for **4 seconds** locks the chord as currently sounding, including the active number-row
  modifier, bass, and voicing. You can then let go of every key and it keeps playing.
- **Feedback:** while held, the button shows a fill/ring progressing over the 4 s so the lock is predictable; on lock,
  a short (~200 ms) pulse and a lock badge on the button. Unlocking fades the badge.
- **Breaking the lock:** any key press breaks it — chord keys, modifiers, arrows, Tab, V, B, Z, everything.
  - Same chord key: breaks the lock and replays the chord as a normal held chord, so it stops when you release. That
    press does not start a new lock timer.
  - Any other key: breaks the lock *and* does its normal action (another chord key plays that chord, arrows shift key, etc.).
  - Key releases never break the lock.
- **Window loses focus:** the lock survives (it's meant to be hands-free); held, unlocked keys still release as today.
- Later, maybe: let sound-only settings change a locked chord without breaking it. Niche, so not now.

## v1.2 — Arpeggiator

Modeled on HiChord's Arpeggio mode:
- Patterns: Up, Down, Up/Down, Down/Up, Random, Fingerpick.
- Rates: 1/1, 1/2, 1/4, 1/8 (default), 1/16, 1/16T, 1/32, Swing 8th, Swing 16th — synced to BPM.
- Gate length tied to release time, as on the device.
- Layering: Arp only, Chord + Arp, Rhythm + Arp.
- A locked chord keeps arpeggiating.
- Stretch, only if it feels right: Strum and Repeat modes (small once the clock exists).

## v1.3 — Sequencer

- Up to 16 steps; each step stores degree, modifier, and bass.
- Enter steps by pressing chord keys; play/stop, move the cursor, replace a step, add/remove 4 steps.
- Plays through the arpeggiator when it's on.

## v1.4 — MIDI out (priority after the sequencer)

Primary use case: driving a **TE OP-1 field over USB-C**. The OP-1 field shows up on the Mac as a class-compliant USB
MIDI device, so this is CoreMIDI output to a chosen destination.
- Choose the MIDI destination (default to an OP-1 field if connected); channel select.
- Send note on/off for everything that sounds: chords, bass, arp, sequencer.
- Optionally send MIDI clock so the OP-1 field's tempo follows the app.
- Toggle whether the built-in synth also plays.
- Verified on a real OP-1 field before merge.

## v1.5 — Sounds

- Sine, triangle, saw, and one natural-sounding instrument (piano-like).

## v1.6 — Effects

- Reverb, BPM-synced delay, and a filter with low-pass and high-pass.

## Later candidates (pick deliberately, not all)

- Presets: save/load a few slots.
- HiChord chord lock (per-button permanent modifier) and the Extended / Chromatic modifier sets.
- Pentatonic and Blues scales — first work out how HiChord derives 7 chords from 5–6-note scales.
- Stereo spread.

## Out of scope

Looper, vocoder, mic sampling, drum machine and loops, Chord Hiro, Ear Trainer, tuner, companion app, and
hardware-only features (battery, USB modes, firmware).

## Keyboard layout (decide before v1.2)

Taken: `A`–`J` chords, `1`–`0` modifiers, arrows, Tab, `Z` `V` `B`.
Proposed: `Q`–`P` row for play/arp/sequencer modes and pattern select, Space for start/stop, `[` `]` for tempo.
