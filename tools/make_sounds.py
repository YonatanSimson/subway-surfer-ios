#!/usr/bin/env python3
"""Synthesise the game's sound effects as WAV files.

Generating them beats sourcing free SFX: no licences to track, the whole set
is consistent, and a tweak is a number in this file rather than a new download.
Everything here is plain stdlib — no numpy, no Pillow.

    python3 tools/make_sounds.py

Writes into SubwaySurfer/Sounds/. Keep them short; these play on top of each
other during a fast run.
"""

import argparse
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
DEFAULT_OUT = Path("SubwaySurfer/Sounds")


def envelope(i, n, attack=0.01, release=0.6):
    """Linear attack, exponential-ish decay, in the range 0..1."""
    t = i / n
    if t < attack:
        return t / attack
    return max(0.0, (1.0 - (t - attack) / (1.0 - attack)) ** (1.0 / release))


def tone(freq_start, freq_end, duration, volume=0.5, harmonics=(1.0, 0.3, 0.12), release=0.6):
    """A pitch sweep with a few harmonics, so it isn't a bare sine."""
    n = int(RATE * duration)
    samples, phase = [], 0.0
    for i in range(n):
        t = i / n
        freq = freq_start + (freq_end - freq_start) * t
        phase += 2 * math.pi * freq / RATE
        value = sum(amp * math.sin(phase * (h + 1)) for h, amp in enumerate(harmonics))
        samples.append(value * envelope(i, n, release=release) * volume)
    return samples


def noise(duration, volume=0.5, lowpass=0.25, release=0.5):
    """Filtered noise — the basis of the slide and the crash."""
    n = int(RATE * duration)
    samples, previous = [], 0.0
    for i in range(n):
        white = random.uniform(-1, 1)
        previous += lowpass * (white - previous)      # one-pole low-pass
        samples.append(previous * envelope(i, n, release=release) * volume)
    return samples


def mix(*tracks):
    """Sum tracks of differing lengths, then clip."""
    out = [0.0] * max(len(t) for t in tracks)
    for track in tracks:
        for i, value in enumerate(track):
            out[i] += value
    return [max(-1.0, min(1.0, v)) for v in out]


def write(path, samples):
    with wave.open(str(path), "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(
            struct.pack("<h", int(v * 32767)) for v in samples
        ))
    print(f"wrote {path} ({len(samples)/RATE:.2f}s)")


def build(out: Path):
    out.mkdir(parents=True, exist_ok=True)
    random.seed(7)   # keep regenerated files identical

    # Jump: a quick upward whoop.
    write(out / "jump.wav", tone(320, 760, 0.18, volume=0.42, release=0.45))

    # Slide: a short filtered-noise sweep, like a scuff along the floor.
    write(out / "slide.wav", mix(
        noise(0.26, volume=0.34, lowpass=0.10, release=0.4),
        tone(420, 180, 0.26, volume=0.16, harmonics=(1.0, 0.2), release=0.4),
    ))

    # Coin: two bright notes a fifth apart, the classic pickup.
    first = tone(1050, 1050, 0.055, volume=0.30, harmonics=(1.0, 0.45, 0.2), release=0.5)
    second = tone(1570, 1570, 0.13, volume=0.30, harmonics=(1.0, 0.45, 0.2), release=0.5)
    write(out / "coin.wav", first + second)

    # Crash: a low thud plus a noise burst.
    write(out / "crash.wav", mix(
        tone(180, 55, 0.42, volume=0.55, harmonics=(1.0, 0.5, 0.25), release=0.85),
        noise(0.34, volume=0.40, lowpass=0.42, release=0.75),
    ))


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT,
                        help=f"directory to write into (default: {DEFAULT_OUT})")
    build(parser.parse_args().out)


if __name__ == "__main__":
    main()
