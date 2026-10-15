# rSplex

A chord synth for macOS, played from the computer keyboard.

    swift run -c release rSplex
    swift test

| Keys | Action |
|---|---|
| A S D F G H J | hold to play the 7 diatonic chords of the key; hold 4 s to lock (any key press unlocks) |
| 1–0 | hold to modify: M/m flip, 7, maj7/m7, add9, sus4, 6/sus2, dim/m, aug, sus2, 5 |
| ← / → | key |
| ↑ / ↓ | octave (-2 to +2) |
| Tab / Shift+Tab | next / previous scale |
| Space | sequencer play / stop |
| Q | record on/off: chord keys write steps at the cursor (SLASH bass: hold the bass key, then the chord) |
| , / . | move the cursor |
| - | rest (while recording) |
| Delete / Shift+Delete | clear the previous step / clear the whole sequence |
| K / Shift+K | add / remove 4 steps (4–16) |
| U / Shift+U | step length: 1/4, 1/2, 1 bar, 2 bars |
| [ / ] | tempo −1 / +1 BPM (40–300) |
| \\ | tap tempo (3+ taps) |
| Z | inversion |
| V | voice leading on/off |
| B | bass: OFF / ROOT / SLASH (hold the bass chord key, then the chord) |
| L | hold-to-lock on/off |
| E | envelope: CLASSIC / SWELL / SHORT |

## Download

Grab **rSplex.zip** from the [latest release](https://github.com/asubichev/rSplex/releases/latest), unzip, and double-click
`rSplex.app`. The first time, right-click it → **Open** → **Open** (the app isn't notarized). If there's no Open option,
use System Settings → Privacy & Security → **Open Anyway**.

## Releasing

Every merge to `main` runs the tests and publishes a release `v<VERSION>.<run number>`. Bump `VERSION` for a new minor line.
To merge without releasing, add the `no-release` label to the PR before merging.
Build locally with `scripts/bundle.sh <version>`.

The app icon is `Resources/AppIcon.png` (1024×1024). To make it from new artwork, run `scripts/compose-icon.swift` (usage at the top of the file).
