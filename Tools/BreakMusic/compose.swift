// Composes and renders Pausie's break-over music: four short, upbeat tracks written for Pausie and
// synthesized here from scratch (no samples, loops or third-party recordings), so they belong to the
// project. Run `Tools/BreakMusic/render.sh` to rebuild `Pausie/Resources/Sounds/*.m4a`.
//
// Usage: swiftc -O compose.swift -o compose && ./compose <output directory>   (writes 32-bit float WAVs)

import AVFoundation
import Foundation

let sampleRate = 44_100.0
/// Every track is 55 s, under the 60 s break-over limit (rule 3), ending on a held chord with a fade.
let trackLength = 55.0
let fadeOutLength = 4.0

// MARK: - Notes

func midi(_ name: String) -> Int {
    let letters: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
    var chars = Array(name)
    var pitch = letters[chars.removeFirst()]!
    if chars.first == "#" {
        pitch += 1
        chars.removeFirst()
    } else if chars.first == "b" {
        pitch -= 1
        chars.removeFirst()
    }
    return 12 * (Int(String(chars))! + 1) + pitch
}

func frequency(_ note: Int) -> Double {
    440 * pow(2, Double(note - 69) / 12)
}

/// The note a diatonic third below, in a major key whose tonic has pitch class `tonic`.
func thirdBelow(_ note: Int, tonic: Int) -> Int {
    let scale = [0, 2, 4, 5, 7, 9, 11]
    let degree = ((note - tonic) % 12 + 12) % 12
    guard let index = scale.firstIndex(of: degree) else { return note - 3 }
    let target = scale[(index + 5) % 7]
    var interval = degree - target
    if interval <= 0 { interval += 12 }
    return note - interval
}

// MARK: - Randomness (seeded, so every render is identical)

struct SplitMix {
    var state: UInt64

    /// -1...1
    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 52) - 1
    }
}

var random = SplitMix(state: 2026)

// MARK: - Filters

struct Biquad {
    private var b0 = 0.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    private var z1 = 0.0, z2 = 0.0

    enum Kind { case lowpass, highpass, bandpass }

    init(_ kind: Kind, _ cutoff: Double, q: Double = 0.707) {
        let w0 = 2 * Double.pi * min(cutoff, sampleRate * 0.45) / sampleRate
        let cosine = cos(w0), alpha = sin(w0) / (2 * q)
        let a0 = 1 + alpha
        switch kind {
        case .lowpass:
            b0 = (1 - cosine) / 2; b1 = 1 - cosine; b2 = (1 - cosine) / 2
        case .highpass:
            b0 = (1 + cosine) / 2; b1 = -(1 + cosine); b2 = (1 + cosine) / 2
        case .bandpass:
            b0 = alpha; b1 = 0; b2 = -alpha
        }
        b0 /= a0; b1 /= a0; b2 /= a0
        a1 = -2 * cosine / a0
        a2 = (1 - alpha) / a0
    }

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }
}

// MARK: - Envelopes

func rise(_ t: Double, _ length: Double) -> Double { t < length ? t / length : 1 }

/// 1 until `end`, then a linear fade to silence over `length`.
func release(_ t: Double, end: Double, length: Double) -> Double {
    t <= end ? 1 : max(0, 1 - (t - end) / length)
}

func render(seconds: Double, _ sample: (Double, Int) -> Double) -> [Double] {
    let count = Int(seconds * sampleRate)
    return (0..<count).map { sample(Double($0) / sampleRate, $0) }
}

// MARK: - Instruments (mono; a note is a MIDI number and a length in seconds)

/// Wooden bars: a few inharmonic partials that die away quickly, plus a soft mallet click.
func marimba(_ note: Int, _ length: Double) -> [Double] {
    let f = frequency(note)
    let decay = 0.5 * pow(523.25 / f, 0.6)
    var click = Biquad(.lowpass, 3500)
    return render(seconds: min(length + decay * 5, 3)) { t, _ in
        var s = sin(2 * .pi * f * t) * exp(-t / decay)
        s += 0.28 * sin(2 * .pi * f * 3.932 * t) * exp(-t / (decay * 0.16))
        s += 0.08 * sin(2 * .pi * f * 9.538 * t) * exp(-t / (decay * 0.05))
        s += click.process(random.next()) * exp(-t / 0.004) * 0.2
        return s * rise(t, 0.0015)
    }
}

/// A plucked string (Karplus–Strong) with a tuned fractional delay: ukulele and guitar-like plucks.
func pluck(_ note: Int, _ length: Double, brightness: Double = 0.5, sustain: Double = 0.996) -> [Double] {
    let period = sampleRate / frequency(note) - 0.5
    let size = Int(period)
    let fraction = period - Double(size)
    let coefficient = (1 - fraction) / (1 + fraction)
    var excitation = Biquad(.lowpass, 900 + 6000 * brightness)
    var line = (0..<size).map { _ in excitation.process(random.next()) }
    var index = 0, allpassIn = 0.0, allpassOut = 0.0
    let ring = length + 0.18
    return render(seconds: ring + 0.02) { t, _ in
        let current = line[index]
        let averaged = sustain * 0.5 * (current + line[(index + 1) % size])
        let tuned = coefficient * averaged + allpassIn - coefficient * allpassOut
        allpassIn = averaged
        allpassOut = tuned
        line[index] = tuned
        index = (index + 1) % size
        return current * release(t, end: length, length: 0.18)
    }
}

/// Kalimba: a tine with a bright FM attack that settles into a pure tone.
func kalimba(_ note: Int, _ length: Double) -> [Double] {
    let f = frequency(note)
    return render(seconds: 1.4) { t, _ in
        let index = 1.1 * exp(-t / 0.045)
        var s = sin(2 * .pi * f * t + index * sin(2 * .pi * 2 * f * t)) * exp(-t / 0.6)
        s += 0.14 * sin(2 * .pi * 5.4 * f * t) * exp(-t / 0.05)
        return s * rise(t, 0.002)
    }
}

/// Soft glassy bell for arpeggios (FM, harmonic ratio, low index).
func bell(_ note: Int, _ length: Double) -> [Double] {
    let f = frequency(note)
    return render(seconds: 1.1) { t, _ in
        let index = 0.7 * exp(-t / 0.12) + 0.1
        return sin(2 * .pi * f * t + index * sin(2 * .pi * 4 * f * t)) * exp(-t / 0.35) * rise(t, 0.002)
    }
}

/// Electric piano: FM tone that mellows as it rings, with a short metallic tine.
func electricPiano(_ note: Int, _ length: Double) -> [Double] {
    let f = frequency(note)
    return render(seconds: length + 0.3) { t, _ in
        let index = 0.9 * exp(-t / 0.45) + 0.2
        var s = sin(2 * .pi * f * t + index * sin(2 * .pi * f * t))
        s += 0.1 * sin(2 * .pi * 14 * f * t) * exp(-t / 0.012)
        return s * exp(-t / 1.4) * rise(t, 0.003) * release(t, end: length, length: 0.25)
    }
}

/// Round bass with a little saturation, so small speakers still hear it through its harmonics.
func bass(_ note: Int, _ length: Double) -> [Double] {
    let f = frequency(note)
    let drive = 1.3
    return render(seconds: length + 0.05) { t, _ in
        let phase = 2 * Double.pi * f * t
        let raw = sin(phase) + 0.4 * sin(2 * phase) + 0.15 * sin(3 * phase)
        let shaped = tanh(drive * raw) / tanh(drive)
        return shaped * rise(t, 0.004) * (0.65 + 0.35 * exp(-t / 0.12)) * release(t, end: length, length: 0.05)
    }
}

func kick() -> [Double] {
    var phase = 0.0
    var click = Biquad(.lowpass, 2500)
    return render(seconds: 0.35) { t, _ in
        phase += 2 * .pi * (48 + 100 * exp(-t / 0.035)) / sampleRate
        return sin(phase) * exp(-t / 0.17) + click.process(random.next()) * exp(-t / 0.002) * 0.25
    }
}

func clap() -> [Double] {
    var band = Biquad(.bandpass, 1400, q: 0.9)
    return render(seconds: 0.3) { t, _ in
        var envelope = 0.0
        for start in [0.0, 0.011, 0.022] where t >= start {
            envelope += exp(-(t - start) / 0.006)
        }
        if t >= 0.022 { envelope += 0.6 * exp(-(t - 0.022) / 0.08) }
        return band.process(random.next()) * envelope * 1.6
    }
}

func shaker() -> [Double] {
    var band = Biquad(.bandpass, 6000, q: 1.1)
    return render(seconds: 0.09) { t, _ in
        band.process(random.next()) * rise(t, 0.012) * exp(-max(0, t - 0.012) / 0.03) * 1.4
    }
}

func hat() -> [Double] {
    var high = Biquad(.highpass, 7500)
    return render(seconds: 0.06) { t, _ in
        high.process(random.next()) * exp(-t / 0.016)
    }
}

// MARK: - Reverb (Freeverb-style combs and allpasses)

struct Comb {
    var buffer: [Double]
    var index = 0
    var store = 0.0
    let feedback: Double
    let damping: Double

    init(_ size: Int, feedback: Double, damping: Double) {
        buffer = Array(repeating: 0, count: size)
        self.feedback = feedback
        self.damping = damping
    }

    mutating func process(_ x: Double) -> Double {
        let y = buffer[index]
        store = y * (1 - damping) + store * damping
        buffer[index] = x + store * feedback
        index = (index + 1) % buffer.count
        return y
    }
}

struct Allpass {
    var buffer: [Double]
    var index = 0

    init(_ size: Int) { buffer = Array(repeating: 0, count: size) }

    mutating func process(_ x: Double) -> Double {
        let delayed = buffer[index]
        buffer[index] = x + delayed * 0.5
        index = (index + 1) % buffer.count
        return delayed - x
    }
}

func reverb(_ input: [Double], spread: Int) -> [Double] {
    var combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617].map { Comb($0 + spread, feedback: 0.82, damping: 0.25) }
    var allpasses = [556, 441, 341, 225].map { Allpass($0 + spread) }
    return input.map { x in
        var y = 0.0
        for i in combs.indices { y += combs[i].process(x * 0.015) }
        for i in allpasses.indices { y = allpasses[i].process(y) }
        return y
    }
}

// MARK: - Mixing

final class Mix {
    var left: [Double]
    var right: [Double]
    var send: [Double]
    let count: Int

    init() {
        count = Int(trackLength * sampleRate)
        left = Array(repeating: 0, count: count)
        right = left
        send = left
    }

    /// Adds a sound at `time` seconds; `pan` is -1 (left) to 1 (right), equal power; `wet` feeds the reverb.
    func add(_ sound: [Double], at time: Double, gain: Double, pan: Double = 0, wet: Double = 0.2) {
        let jitter = random.next() * 0.002
        let start = Int(max(0, time + jitter) * sampleRate)
        let velocity = gain * (1 + random.next() * 0.06)
        let angle = (pan + 1) * Double.pi / 4
        let (gl, gr) = (cos(angle) * velocity, sin(angle) * velocity)
        for (i, s) in sound.enumerated() {
            let j = start + i
            guard j < count else { break }
            left[j] += s * gl
            right[j] += s * gr
            send[j] += s * velocity * wet
        }
    }

    /// Reverb, gentle filtering and soft clipping, fades, then a peak normalize; loudness is set later.
    func master() -> (left: [Double], right: [Double]) {
        let wetLeft = reverb(send, spread: 0)
        let wetRight = reverb(send, spread: 23)
        var outLeft = [Double](repeating: 0, count: count)
        var outRight = outLeft
        var filters = [Biquad(.highpass, 35), Biquad(.highpass, 35), Biquad(.lowpass, 11000), Biquad(.lowpass, 11000)]
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let fade = rise(t, 0.01) * min(1, max(0, (trackLength - t) / fadeOutLength))
            let shapedFade = sin(fade * Double.pi / 2)
            var l = left[i] + wetLeft[i] * 3
            var r = right[i] + wetRight[i] * 3
            l = filters[2].process(filters[0].process(l))
            r = filters[3].process(filters[1].process(r))
            outLeft[i] = tanh(l * 0.9) * shapedFade
            outRight[i] = tanh(r * 0.9) * shapedFade
        }
        let peak = max(outLeft.map(abs).max() ?? 1, outRight.map(abs).max() ?? 1)
        let scale = 0.89 / max(peak, 0.0001)
        return (outLeft.map { $0 * scale }, outRight.map { $0 * scale })
    }
}

// MARK: - Arrangement helpers

/// A note in a phrase: start and length in eighth notes from the phrase's first bar.
typealias Event = (step: Double, length: Double, note: String)

struct Song {
    let bpm: Double
    var eighth: Double { 60 / bpm / 2 }
    var bar: Double { eighth * 8 }

    func time(bar: Int, step: Double = 0) -> Double { Double(bar) * self.bar + step * eighth }
}

func melody(
    _ events: [Event], song: Song, from bar: Int, into mix: Mix,
    instrument: (Int, Double) -> [Double], gain: Double, pan: Double = 0, wet: Double = 0.2,
    transpose: Int = 0, harmonyTonic: Int? = nil, harmonyGain: Double = 0.5
) {
    for event in events {
        let note = midi(event.note) + transpose
        let at = song.time(bar: bar, step: event.step)
        let length = event.length * song.eighth
        mix.add(instrument(note, length), at: at, gain: gain, pan: pan, wet: wet)
        if let harmonyTonic {
            mix.add(instrument(thirdBelow(note, tonic: harmonyTonic), length), at: at, gain: gain * harmonyGain, pan: -pan, wet: wet)
        }
    }
}

/// Bass line from a per-bar pattern of (step, length, semitones above the root).
func bassLine(_ roots: [String], song: Song, from bar: Int, pattern: [(Double, Double, Int)], into mix: Mix, gain: Double) {
    for (offset, root) in roots.enumerated() {
        for (step, length, interval) in pattern {
            let at = song.time(bar: bar + offset, step: step)
            mix.add(bass(midi(root) + interval, length * song.eighth), at: at, gain: gain, wet: 0.05)
        }
    }
}

/// Drum hits on eighth-note steps of each bar. `swing` delays the off-beats by that share of an eighth.
func drums(
    bars: Range<Int>, song: Song, into mix: Mix,
    kicks: [Double] = [], claps: [Double] = [], shakers: [Double] = [], hats: [Double] = [],
    kickGain: Double = 0.55, clapGain: Double = 0.16, shakerGain: Double = 0.07, hatGain: Double = 0.05,
    swing: Double = 0
) {
    let sounds = (kick: kick(), clap: clap(), shaker: shaker(), hat: hat())
    for bar in bars {
        func at(_ step: Double) -> Double {
            let isOffbeat = step.truncatingRemainder(dividingBy: 1) == 0 && Int(step) % 2 == 1
            return song.time(bar: bar, step: step + (isOffbeat ? swing : 0))
        }
        for step in kicks { mix.add(sounds.kick, at: at(step), gain: kickGain, wet: 0.02) }
        for step in claps { mix.add(sounds.clap, at: at(step), gain: clapGain, pan: 0.1, wet: 0.25) }
        for step in shakers { mix.add(sounds.shaker, at: at(step), gain: shakerGain * (Int(step) % 2 == 1 ? 1 : 0.6), pan: 0.35, wet: 0.1) }
        for step in hats { mix.add(sounds.hat, at: at(step), gain: hatGain * (Int(step) % 2 == 1 ? 1 : 0.7), pan: -0.3, wet: 0.05) }
    }
}

func chordNotes(_ names: [String]) -> [Int] { names.map(midi) }

// MARK: - Track 1: Morning Marimba (C major, 118 BPM)

func morningMarimba() -> Mix {
    let song = Song(bpm: 118)
    let mix = Mix()
    let voicing: [String: [String]] = [
        "C": ["E4", "G4", "C5"], "G": ["D4", "G4", "B4"], "Am": ["E4", "A4", "C5"],
        "F": ["F4", "A4", "C5"], "Dm": ["F4", "A4", "D5"],
    ]
    let root: [String: String] = ["C": "C3", "G": "G2", "Am": "A2", "F": "F2", "Dm": "D3"]
    let verse = ["C", "G", "Am", "F"]
    let bridge = ["Am", "F", "C", "G", "Am", "F", "Dm", "G"]
    let chords = verse + verse + verse + bridge + verse
    let hook: [Event] = [
        (0, 1, "E5"), (1, 1, "G5"), (2, 2, "C6"), (4, 1, "G5"), (5, 1, "E5"), (6, 1, "G5"), (7, 1, "A5"),
        (8, 1, "B5"), (9, 1, "G5"), (10, 2, "D5"), (12, 1, "G5"), (13, 1, "B5"), (14, 2, "D6"),
        (16, 1, "C6"), (17, 1, "A5"), (18, 2, "E5"), (20, 1, "A5"), (21, 1, "C6"), (22, 1, "B5"), (23, 1, "A5"),
        (24, 2, "A5"), (26, 1, "G5"), (27, 1, "F5"), (28, 1, "E5"), (29, 1, "F5"), (30, 2, "G5"),
    ]
    let bridgeTune: [Event] = [
        (0, 2, "E5"), (2, 2, "A5"), (4, 3, "C6"), (7, 1, "B5"),
        (8, 2, "A5"), (10, 2, "F5"), (12, 4, "C6"),
        (16, 2, "G5"), (18, 2, "E5"), (20, 2, "G5"), (22, 2, "C6"),
        (24, 4, "B5"), (28, 2, "D6"), (30, 2, "B5"),
        (32, 2, "C6"), (34, 2, "B5"), (36, 3, "A5"), (39, 1, "G5"),
        (40, 2, "A5"), (42, 2, "C6"), (44, 4, "F5"),
        (48, 2, "F5"), (50, 2, "A5"), (52, 2, "D6"), (54, 2, "C6"),
        (56, 3, "B5"), (59, 1, "A5"), (60, 2, "G5"), (62, 2, "D5"),
    ]
    for bar in [0, 4, 8, 20] {
        melody(hook, song: song, from: bar, into: mix, instrument: marimba, gain: 0.5, pan: -0.1,
               harmonyTonic: bar >= 8 ? 0 : nil, harmonyGain: 0.35)
    }
    melody(bridgeTune, song: song, from: 12, into: mix, instrument: marimba, gain: 0.5, pan: -0.1, harmonyTonic: 0, harmonyGain: 0.3)

    for (bar, chord) in chords.enumerated() {
        for step in [1.0, 3, 5, 7] {
            for (i, note) in chordNotes(voicing[chord]!).enumerated() {
                mix.add(pluck(note, song.eighth * 0.9, brightness: 0.35), at: song.time(bar: bar, step: step) + Double(i) * 0.008,
                        gain: 0.16, pan: 0.35, wet: 0.2)
            }
        }
    }
    bassLine(chords.map { root[$0]! }, song: song, from: 0, pattern: [(0, 1.5, 0), (3, 1, 0), (4, 1, 12), (6, 2, 0)], into: mix, gain: 0.32)
    drums(bars: 0..<24, song: song, into: mix, kicks: [0, 4], shakers: [0, 1, 2, 3, 4, 5, 6, 7])
    drums(bars: 4..<24, song: song, into: mix, claps: [2, 6])

    let end = 24
    for note in ["C5", "E5", "G5", "C6"] {
        mix.add(marimba(midi(note), 2), at: song.time(bar: end), gain: 0.45, wet: 0.35)
    }
    mix.add(bass(midi("C3"), 2.5), at: song.time(bar: end), gain: 0.32)
    mix.add(kick(), at: song.time(bar: end), gain: 0.55)
    return mix
}

// MARK: - Track 2: Ukulele Bounce (G major, 124 BPM)

func ukuleleBounce() -> Mix {
    let song = Song(bpm: 124)
    let mix = Mix()
    let voicing: [String: [String]] = [
        "G": ["G4", "B4", "D5", "G5"], "Em": ["G4", "B4", "E5", "G5"], "C": ["G4", "C5", "E5", "G5"],
        "D": ["F#4", "A4", "D5", "F#5"], "Bm": ["F#4", "B4", "D5", "F#5"],
    ]
    let root: [String: String] = ["G": "G2", "Em": "E2", "C": "C3", "D": "D3", "Bm": "B2"]
    let verse = ["G", "Em", "C", "D"]
    let bridge = ["C", "D", "G", "Em", "C", "D", "G", "D"]
    let chords = verse + verse + bridge + verse + verse + ["C", "D"]
    let hook: [Event] = [
        (0, 1, "B5"), (1, 1, "D6"), (2, 1, "B5"), (3, 1, "G5"), (4, 2, "A5"), (6, 2, "B5"),
        (8, 1, "G5"), (9, 1, "B5"), (10, 1, "G5"), (11, 1, "E5"), (12, 2, "F#5"), (14, 2, "G5"),
        (16, 1, "E5"), (17, 1, "G5"), (18, 1, "C6"), (19, 1, "B5"), (20, 2, "A5"), (22, 1, "G5"), (23, 1, "E5"),
        (24, 2, "F#5"), (26, 1, "A5"), (27, 1, "D6"), (28, 3, "C6"), (31, 1, "A5"),
    ]
    let bridgeTune: [Event] = [
        (0, 2, "G5"), (2, 2, "E5"), (4, 2, "C6"), (6, 2, "B5"),
        (8, 2, "A5"), (10, 2, "F#5"), (12, 4, "D5"),
        (16, 2, "B5"), (18, 2, "D6"), (20, 2, "B5"), (22, 2, "G5"),
        (24, 4, "E5"), (28, 2, "G5"), (30, 2, "B5"),
        (32, 2, "C6"), (34, 2, "B5"), (36, 2, "A5"), (38, 2, "G5"),
        (40, 2, "F#5"), (42, 2, "A5"), (44, 4, "D6"),
        (48, 2, "B5"), (50, 1, "A5"), (51, 1, "G5"), (52, 4, "G5"),
        (56, 2, "A5"), (58, 2, "F#5"), (60, 2, "D5"), (62, 2, "F#5"),
    ]
    let turnaround: [Event] = [(0, 1, "E5"), (1, 1, "G5"), (2, 1, "C6"), (3, 1, "B5"), (4, 2, "A5"), (6, 2, "G5"),
                               (8, 1, "F#5"), (9, 1, "A5"), (10, 1, "D6"), (11, 1, "C6"), (12, 2, "B5"), (14, 2, "A5")]
    for bar in [0, 4, 16, 20] {
        melody(hook, song: song, from: bar, into: mix, instrument: kalimba, gain: 0.42, pan: 0.15,
               harmonyTonic: bar == 20 ? 7 : nil, harmonyGain: 0.4)
    }
    melody(bridgeTune, song: song, from: 8, into: mix, instrument: kalimba, gain: 0.42, pan: 0.15)
    melody(turnaround, song: song, from: 24, into: mix, instrument: kalimba, gain: 0.42, pan: 0.15)

    // Island strum: down, down-up, up-down-up. Up-strums are lighter and run high to low.
    let strum: [(Double, Bool)] = [(0, true), (2, true), (3, false), (5, false), (6, true), (7, false)]
    for (bar, chord) in chords.enumerated() {
        let notes = chordNotes(voicing[chord]!)
        for (step, down) in strum {
            let order = down ? notes : notes.reversed()
            for (i, note) in order.enumerated() {
                mix.add(pluck(note, song.eighth * 1.6, brightness: 0.6, sustain: 0.995),
                        at: song.time(bar: bar, step: step) + Double(i) * 0.011, gain: down ? 0.17 : 0.11, pan: -0.3, wet: 0.18)
            }
        }
    }
    bassLine(chords.map { root[$0]! }, song: song, from: 0, pattern: [(0, 2, 0), (3, 1, 0), (4, 2, 7), (6, 2, 0)], into: mix, gain: 0.3)
    drums(bars: 0..<26, song: song, into: mix, shakers: [0, 1, 2, 3, 4, 5, 6, 7])
    drums(bars: 4..<26, song: song, into: mix, kicks: [0, 4], claps: [2, 6], clapGain: 0.13)

    let end = 26
    for note in ["G4", "B4", "D5", "G5"] {
        mix.add(pluck(midi(note), 3, brightness: 0.6, sustain: 0.998), at: song.time(bar: end), gain: 0.2, pan: -0.3, wet: 0.3)
    }
    mix.add(kalimba(midi("G5"), 1), at: song.time(bar: end), gain: 0.42, pan: 0.15, wet: 0.35)
    mix.add(bass(midi("G2"), 2.5), at: song.time(bar: end), gain: 0.3)
    mix.add(kick(), at: song.time(bar: end), gain: 0.55)
    return mix
}

// MARK: - Track 3: Rise & Shine (D major, 116 BPM; it builds up)

func riseAndShine() -> Mix {
    let song = Song(bpm: 116)
    let mix = Mix()
    let voicing: [String: [String]] = [
        "D": ["D4", "F#4", "A4"], "A": ["C#4", "E4", "A4"], "Bm": ["D4", "F#4", "B4"], "G": ["D4", "G4", "B4"],
    ]
    let root: [String: String] = ["D": "D3", "A": "A2", "Bm": "B2", "G": "G2"]
    let loop = ["D", "A", "Bm", "G"]
    let chords = Array(repeating: loop, count: 6).flatMap { $0 }
    let hook: [Event] = [
        (0, 3, "F#5"), (3, 1, "E5"), (4, 2, "D5"), (6, 2, "A5"),
        (8, 3, "E5"), (11, 1, "C#5"), (12, 2, "E5"), (14, 2, "A5"),
        (16, 3, "F#5"), (19, 1, "E5"), (20, 2, "D5"), (22, 2, "B5"),
        (24, 3, "A5"), (27, 1, "G5"), (28, 4, "F#5"),
        (32, 2, "A5"), (34, 2, "D6"), (36, 2, "C#6"), (38, 2, "A5"),
        (40, 3, "B5"), (43, 1, "A5"), (44, 4, "E5"),
        (48, 2, "F#5"), (50, 2, "A5"), (52, 2, "B5"), (54, 2, "D6"),
        (56, 3, "C#6"), (59, 1, "B5"), (60, 2, "A5"), (62, 2, "E5"),
    ]
    melody(hook, song: song, from: 8, into: mix, instrument: marimba, gain: 0.48, pan: -0.15)
    melody(hook, song: song, from: 16, into: mix, instrument: marimba, gain: 0.48, pan: -0.15, harmonyTonic: 2, harmonyGain: 0.4)

    // Rising bell arpeggio in sixteenths across two octaves of each chord.
    let shape = [0, 1, 2, 3, 4, 5, 4, 3, 1, 2, 3, 4, 5, 4, 3, 2]
    for (bar, chord) in chords.enumerated() {
        let base = chordNotes(voicing[chord]!)
        let tones = base + base.map { $0 + 12 }
        for (i, index) in shape.enumerated() {
            let accent = i % 4 == 0 ? 1.0 : 0.7
            mix.add(bell(tones[index], song.eighth / 2), at: song.time(bar: bar, step: Double(i) / 2),
                    gain: 0.12 * accent, pan: i % 2 == 0 ? 0.4 : 0.2, wet: 0.3)
        }
    }
    bassLine(chords[4...].map { root[$0]! }, song: song, from: 4,
             pattern: [(0, 1, 0), (1, 1, 0), (2, 1, 0), (3, 1, 0), (4, 1, 0), (5, 1, 0), (6, 1, 12), (7, 1, 0)], into: mix, gain: 0.26)
    drums(bars: 0..<24, song: song, into: mix, kicks: [0, 2, 4, 6], kickGain: 0.45)
    drums(bars: 4..<24, song: song, into: mix, claps: [2, 6], clapGain: 0.14)
    drums(bars: 16..<24, song: song, into: mix, hats: [1, 3, 5, 7], hatGain: 0.06)

    let end = 24
    for note in ["D5", "F#5", "A5", "D6"] {
        mix.add(marimba(midi(note), 2), at: song.time(bar: end), gain: 0.42, wet: 0.35)
        mix.add(bell(midi(note) - 12, 1), at: song.time(bar: end), gain: 0.12, pan: 0.3, wet: 0.4)
    }
    mix.add(bass(midi("D3"), 2.5), at: song.time(bar: end), gain: 0.28)
    mix.add(kick(), at: song.time(bar: end), gain: 0.5)
    return mix
}

// MARK: - Track 4: Happy Groove (F major, 108 BPM, light swing)

func happyGroove() -> Mix {
    let song = Song(bpm: 108)
    let mix = Mix()
    let voicing: [String: [String]] = [
        "Fmaj7": ["F3", "A3", "C4", "E4"], "Am7": ["G3", "A3", "C4", "E4"], "Bbmaj7": ["F3", "A3", "Bb3", "D4"],
        "C": ["G3", "C4", "E4"], "C7": ["G3", "Bb3", "C4", "E4"], "Dm7": ["F3", "A3", "C4", "D4"],
        "Gm7": ["F3", "G3", "Bb3", "D4"], "Bb": ["F3", "Bb3", "D4"],
    ]
    let root: [String: String] = ["Fmaj7": "F2", "Am7": "A2", "Bbmaj7": "Bb2", "C": "C3", "C7": "C3", "Dm7": "D3", "Gm7": "G2", "Bb": "Bb2"]
    let verse = ["Fmaj7", "Am7", "Bbmaj7", "C7"]
    let bridge = ["Dm7", "Gm7", "Bbmaj7", "C", "Dm7", "Gm7", "Bb", "C7"]
    let chords = verse + verse + bridge + verse + ["Bbmaj7", "C7"]
    let hook: [Event] = [
        (0, 1, "A5"), (1, 1, "C6"), (2, 1, "A5"), (3, 1, "G5"), (4, 2, "F5"), (6, 1, "G5"), (7, 1, "A5"),
        (8, 2, "C6"), (10, 1, "A5"), (11, 1, "G5"), (12, 2, "E5"), (14, 1, "G5"), (15, 1, "A5"),
        (16, 1, "Bb5"), (17, 1, "A5"), (18, 1, "G5"), (19, 1, "F5"), (20, 2, "D5"), (22, 2, "F5"),
        (24, 2, "E5"), (26, 1, "G5"), (27, 1, "Bb5"), (28, 4, "C6"),
    ]
    let bridgeTune: [Event] = [
        (0, 2, "F5"), (2, 2, "A5"), (4, 2, "C6"), (6, 2, "A5"),
        (8, 2, "Bb5"), (10, 2, "G5"), (12, 4, "D5"),
        (16, 2, "F5"), (18, 1, "G5"), (19, 1, "A5"), (20, 4, "Bb5"),
        (24, 2, "C6"), (26, 2, "Bb5"), (28, 2, "G5"), (30, 2, "E5"),
        (32, 2, "D5"), (34, 2, "F5"), (36, 2, "A5"), (38, 2, "D6"),
        (40, 3, "C6"), (43, 1, "Bb5"), (44, 4, "G5"),
        (48, 2, "A5"), (50, 2, "Bb5"), (52, 2, "C6"), (54, 2, "D6"),
        (56, 4, "C6"), (60, 2, "Bb5"), (62, 2, "G5"),
    ]
    let lead: (Int, Double) -> [Double] = { pluck($0, $1, brightness: 0.75, sustain: 0.997) }
    for bar in [0, 4, 16] {
        melody(hook, song: song, from: bar, into: mix, instrument: lead, gain: 0.5, pan: 0.1, wet: 0.25)
    }
    melody(bridgeTune, song: song, from: 8, into: mix, instrument: lead, gain: 0.5, pan: 0.1, wet: 0.25, harmonyTonic: 5, harmonyGain: 0.35)
    let tag: [Event] = [(0, 1, "A5"), (1, 1, "C6"), (2, 1, "A5"), (3, 1, "G5"), (4, 2, "F5"), (6, 2, "D5"),
                        (8, 2, "E5"), (10, 1, "G5"), (11, 1, "Bb5"), (12, 4, "C6")]
    melody(tag, song: song, from: 20, into: mix, instrument: lead, gain: 0.5, pan: 0.1, wet: 0.25)

    // Electric piano on a syncopated "one, and-of-two, and-of-three" figure.
    let comp: [(Double, Double)] = [(0, 1.5), (3, 1), (5, 2)]
    for (bar, chord) in chords.enumerated() {
        for (step, length) in comp {
            for note in chordNotes(voicing[chord]!) {
                mix.add(electricPiano(note, length * song.eighth), at: song.time(bar: bar, step: step), gain: 0.13, pan: -0.25, wet: 0.3)
            }
        }
    }
    bassLine(chords.map { root[$0]! }, song: song, from: 0,
             pattern: [(0, 1, 0), (2, 0.8, 12), (3, 1, 0), (5, 1, 7), (6, 1, 0), (7, 0.8, 10)], into: mix, gain: 0.32)
    drums(bars: 0..<22, song: song, into: mix, kicks: [0, 3, 4], claps: [2, 6], hats: [0, 1, 2, 3, 4, 5, 6, 7],
          clapGain: 0.15, hatGain: 0.05, swing: 0.16)

    let end = 22
    for note in voicing["Fmaj7"]! {
        mix.add(electricPiano(midi(note), 3), at: song.time(bar: end), gain: 0.14, pan: -0.25, wet: 0.35)
    }
    mix.add(lead(midi("F5"), 2.5), at: song.time(bar: end), gain: 0.45, pan: 0.1, wet: 0.35)
    mix.add(bass(midi("F2"), 2.5), at: song.time(bar: end), gain: 0.32)
    mix.add(kick(), at: song.time(bar: end), gain: 0.55)
    return mix
}

// MARK: - Output

func writeWAV(_ mix: Mix, to url: URL) throws {
    let (left, right) = mix.master()
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(left.count))!
    buffer.frameLength = AVAudioFrameCount(left.count)
    for i in 0..<left.count {
        buffer.floatChannelData![0][i] = Float(left[i])
        buffer.floatChannelData![1][i] = Float(right[i])
    }
    var settings = format.settings
    settings[AVLinearPCMIsNonInterleaved] = false
    let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
    try file.write(from: buffer)
}

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let tracks: [(String, () -> Mix)] = [
    ("morning-marimba", morningMarimba),
    ("ukulele-bounce", ukuleleBounce),
    ("rise-and-shine", riseAndShine),
    ("happy-groove", happyGroove),
]
for (name, compose) in tracks {
    try writeWAV(compose(), to: output.appending(path: "\(name).wav"))
    print("Rendered \(name).wav")
}
