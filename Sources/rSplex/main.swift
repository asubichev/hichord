import Cocoa
import AVFoundation
import rSplexCore

let degreeKeys = ["a", "s", "d", "f", "g", "h", "j"]
let modKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

final class Synth {
    let engine = AVAudioEngine()
    let lock = NSLock()
    private var freqs: [Double] = []
    private var gate = false
    private var cur: [Double] = []
    private var phases = [Double](repeating: 0, count: 32)
    private var env = 0.0, lp = 0.0

    init() {
        let sr = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let fmt = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1)!
        let src = AVAudioSourceNode(format: fmt) { [unowned self] _, _, frameCount, abl in
            let bufs = UnsafeMutableAudioBufferListPointer(abl)
            self.lock.lock(); let f = self.freqs; let g = self.gate; self.lock.unlock()
            if g { self.cur = f }
            let atk = 1.0 / (0.005 * sr), rel = 1.0 / (0.3 * sr)
            let out = bufs[0].mData!.assumingMemoryBound(to: Float.self)
            let n = min(self.cur.count, 16)
            for i in 0..<Int(frameCount) {
                self.env = g ? min(1, self.env + atk) : max(0, self.env - rel)
                var s = 0.0
                for k in 0..<n {
                    // Each note gets a slightly detuned partner oscillator.
                    for (j, det) in [(2 * k, 0.9985), (2 * k + 1, 1.0015)] {
                        self.phases[j] += self.cur[k] * det / sr
                        if self.phases[j] >= 1 { self.phases[j] -= 1 }
                        let p = self.phases[j]
                        s += 0.25 * (2 * p - 1) + 0.25 * sin(2 * .pi * p)
                    }
                }
                if n > 0 { s /= Double(n) }
                self.lp += 0.2 * (s - self.lp)
                out[i] = Float(self.lp * self.env * 0.35)
            }
            return noErr
        }
        engine.attach(src)
        engine.connect(src, to: engine.mainMixerNode, format: fmt)
        do { try engine.start() } catch { print("Audio failed: \(error)") }
    }

    func play(midi: [Int]) {
        lock.lock(); freqs = midi.map { 440 * pow(2, Double($0 - 69) / 12) }; gate = true; lock.unlock()
    }
    func stop() { lock.lock(); gate = false; lock.unlock() }
}

final class ChordView: NSView {
    let synth = Synth()
    var state = RSplexState()
    var display = "—"
    /// Lock animation: when the current lock started (pulse), and the degree/time of the last unlock (badge fade).
    var lockedAt: Double?
    var unlocked: (degree: Int, at: Double)?
    var timer: Timer?
    static let pulseSeconds = 0.25, fadeSeconds = 0.3
    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    var now: Double { ProcessInfo.processInfo.systemUptime }

    override func viewDidMoveToWindow() {
        guard timer == nil else { return }
        // Drives the lock timer and its animation; idle frames do nothing.
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func tick() {
        let t = now
        let animating = lockedAt.map { t - $0 < Self.pulseSeconds } == true
            || unlocked.map { t - $0.at < Self.fadeSeconds } == true
        if state.lockProgress(now: t) != nil || animating { update() }
    }

    func update() {
        let wasLocked = state.lock != nil
        if let out = state.render(now: now) { synth.play(midi: out.notes); display = out.name }
        else { synth.stop(); display = "—" }
        if !wasLocked, state.lock != nil { lockedAt = now }
        needsDisplay = true
    }

    override func keyDown(with e: NSEvent) {
        let c = e.charactersIgnoringModifiers?.lowercased() ?? ""
        let isArrowOrTab = [123, 124, 125, 126, 48].contains(e.keyCode)
        if e.isARepeat && !isArrowOrTab { return }
        // Any key press breaks a lock; the press then does its normal job.
        let degree = degreeKeys.firstIndex(of: c)
        if let d = state.breakLock(pressingDegree: degree) { unlocked = (d, now); lockedAt = nil }
        switch e.keyCode {
        case 123: state.shiftKey(-1)
        case 124: state.shiftKey(1)
        case 125: state.shiftOctave(-1)
        case 126: state.shiftOctave(1)
        case 48: e.modifierFlags.contains(.shift) ? state.previousScale() : state.nextScale()
        default:
            if let d = degree { state.press(degree: d) }
            else if let m = modKeys.firstIndex(of: c) { state.press(mod: m) }
            else if c == "z" { state.cycleInversion() }
            else if c == "v" { state.voiceLeading.toggle() }
            else if c == "b" { state.cycleBass() }
            else if c == "l" { state.lockEnabled.toggle() }
            else { update(); super.keyDown(with: e); return }
        }
        update()
    }

    override func keyUp(with e: NSEvent) {
        guard let c = e.charactersIgnoringModifiers?.lowercased() else { return }
        if let d = degreeKeys.firstIndex(of: c) { state.release(degree: d); update() }
        else if let m = modKeys.firstIndex(of: c) { state.release(mod: m); update() }
    }

    /// Releases held keys (e.g. the window lost focus); a lock keeps playing.
    func releaseAll() { state.releaseAll(); update() }

    override func draw(_ dirty: NSRect) {
        NSColor(white: 0.12, alpha: 1).setFill(); bounds.fill()
        let big: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 40), .foregroundColor: NSColor.white]
        let mid: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 22), .foregroundColor: NSColor.white]
        let small: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.lightGray]
        let s = state, t = now
        display.draw(at: NSPoint(x: 20, y: 12), withAttributes: big)
        if s.lock != nil {
            let x = 24 + display.size(withAttributes: big).width
            drawLockBadge(at: NSPoint(x: x, y: 26), size: 20, alpha: 1)
        }
        "Key \(noteNames[s.key]) \(scales[s.scaleIdx].name)".draw(at: NSPoint(x: 20, y: 66), withAttributes: small)
        let settings = "Oct \(s.octave >= 0 ? "+" : "")\(s.octave)   Inv \(s.voiceLeading ? "auto" : String(s.inversion))   "
            + "VoiceLead \(s.voiceLeading ? "ON" : "OFF")   Bass \(bassModes[s.bassMode])   Lock \(s.lockEnabled ? "ON" : "OFF")"
        let settingsWidth = settings.size(withAttributes: small).width
        settings.draw(at: NSPoint(x: bounds.width - 20 - settingsWidth, y: 66), withAttributes: small)
        let gap: CGFloat = 8
        let w = (bounds.width - 40 - 6 * gap) / 7
        for d in 0..<7 {
            let rect = NSRect(x: 20 + CGFloat(d) * (w + gap), y: 92, width: w, height: 90)
            let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
            let sounding = s.lock?.degree == d || (s.lock == nil && s.held.last == d)
            (sounding ? NSColor.systemOrange : s.held.contains(d) ? NSColor.systemBrown : NSColor(white: 0.25, alpha: 1)).setFill()
            path.fill()
            // Lock timer: the held button fills bottom-up with a lighter tint over the hold time.
            if s.held.last == d, let p = s.lockProgress(now: t), p > 0 {
                NSGraphicsContext.saveGraphicsState()
                path.addClip()
                NSColor.white.withAlphaComponent(0.28).setFill()
                NSRect(x: rect.minX, y: rect.maxY - rect.height * p, width: rect.width, height: rect.height * p).fill()
                NSGraphicsContext.restoreGraphicsState()
            }
            chord(degree: d, key: s.key, scale: s.scale, mod: nil).name
                .draw(at: NSPoint(x: rect.minX + 8, y: rect.minY + 12), withAttributes: mid)
            degreeKeys[d].uppercased().draw(at: NSPoint(x: rect.minX + 8, y: rect.maxY - 20), withAttributes: small)
            let badge = NSPoint(x: rect.maxX - 24, y: rect.maxY - 26)
            if s.lock?.degree == d {
                drawLockBadge(at: badge, size: 16, alpha: 1)
                // Lock pulse: an outline that grows and fades right after locking.
                if let at = lockedAt, t - at < Self.pulseSeconds {
                    let k = CGFloat((t - at) / Self.pulseSeconds)
                    let ring = NSBezierPath(roundedRect: rect.insetBy(dx: -10 * k, dy: -10 * k), xRadius: 10 + 10 * k, yRadius: 10 + 10 * k)
                    NSColor.systemOrange.withAlphaComponent(1 - k).setStroke()
                    ring.lineWidth = 3
                    ring.stroke()
                }
            } else if let u = unlocked, u.degree == d, t - u.at < Self.fadeSeconds {
                drawLockBadge(at: badge, size: 16, alpha: 1 - (t - u.at) / Self.fadeSeconds)
            }
        }
        let qw = (bounds.width - 40 - 9 * 6) / 10
        for i in 0..<10 {
            let rect = NSRect(x: 20 + CGFloat(i) * (qw + 6), y: 198, width: qw, height: 50)
            // A locked chord keeps its modifier lit after the key is released.
            let active = s.lock.map { $0.mod == i } ?? (s.mods.last == i)
            (active ? NSColor.systemTeal : NSColor(white: 0.22, alpha: 1)).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
            modKeys[i].draw(at: NSPoint(x: rect.minX + 5, y: rect.minY + 4), withAttributes: small)
            modLabels[i].draw(at: NSPoint(x: rect.minX + 5, y: rect.minY + 26), withAttributes: small)
        }
        "Hold A–J = chords (4 s locks) · hold 1–0 = modify · ←/→ key · ↑/↓ oct · Tab/⇧Tab scale · Z inv · V lead · B bass · L lock"
            .draw(at: NSPoint(x: 20, y: 262), withAttributes: small)
    }

    func drawLockBadge(at p: NSPoint, size: CGFloat, alpha: Double) {
        guard let img = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Locked")?
            .withSymbolConfiguration(.init(pointSize: size, weight: .bold)) else { return }
        let tinted = NSImage(size: img.size, flipped: false) { r in
            img.draw(in: r)
            NSColor.white.set()
            r.fill(using: .sourceAtop)
            return true
        }
        tinted.draw(in: NSRect(origin: p, size: img.size), from: .zero, operation: .sourceOver, fraction: alpha, respectFlipped: true, hints: nil)
    }
}

final class Delegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let view = ChordView()
    func applicationDidFinishLaunching(_ n: Notification) {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 290),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "rSplex"
        window.contentView = view
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
        NSApp.activate(ignoringOtherApps: true)
    }
    func windowDidResignKey(_ n: Notification) { view.releaseAll() }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = Delegate()
app.delegate = delegate
app.run()
