# HiChord (keyboard)

A HiChord-style chord synth for macOS, played from the computer keyboard.

    swift run -c release HiChord
    swift test

| Keys | Action |
|---|---|
| A S D F G H J | hold to play the 7 diatonic chords of the key |
| 1–0 | hold to modify: M/m flip, 7, maj7/m7, add9, sus4, 6/sus2, m/dim, aug, sus2, 5 |
| ← / → | key |
| ↑ / ↓ | octave (-1 to +2) |
| Tab | scale |
| Z | inversion |
| V | voice leading on/off |
| B | bass: OFF / ROOT / SLASH (hold the bass chord key, then the chord) |

## Download

Grab **HiChord.zip** from the [latest release](https://github.com/asubichev/hichord/releases/latest), unzip, and double-click
`HiChord.app`. The first time, right-click it → **Open** → **Open** (the app isn't notarized). If there's no Open option,
use System Settings → Privacy & Security → **Open Anyway**.

## Releasing

Every merge to `main` runs the tests and publishes a release `v<VERSION>.<run number>`. Bump `VERSION` for a new minor line.
Build locally with `scripts/bundle.sh <version>`.
