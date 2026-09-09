#!/usr/bin/env python3
"""Generate the 13 combat/training SFX as short one-shot files.

Pure stdlib. Deterministic: fixed seed -> byte-identical WAVs. Writes
16-bit mono 44.1 kHz WAV into assets/audio/. If `ffmpeg` is on PATH,
transcodes each to .ogg (-q:a 3) and removes the .wav.

Re-run after editing a recipe:  python3 tools/gen_sfx.py
"""
import math
import os
import random
import shutil
import struct
import subprocess
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), os.pardir, "assets", "audio")

# The 13 SoundCue names, verbatim (must match lib/core/platform/game_audio.dart).
CUES = [
    "uiTap", "strikeDull", "strikeWeapon", "strikeTechnique", "strikePerfect",
    "strikeMiss", "guardHold", "bodyBlow", "waveStart", "sessionEnd",
    "techniqueEvolved", "fightWon", "fightLost",
]


def _env(n, attack, release):
    """Linear attack / exponential-ish release envelope, length n samples."""
    a = max(1, int(attack * SR))
    r = max(1, int(release * SR))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            k = (i - a) / max(1, r)
            out.append(math.exp(-3.0 * k))
    return out


def _tone(freq, dur, attack=0.004, release=0.12, kind="sine", glide=0.0):
    n = int(dur * SR)
    env = _env(n, attack, release)
    s = []
    ph = 0.0
    for i in range(n):
        f = freq * (1.0 + glide * i / n)
        ph += 2 * math.pi * f / SR
        if kind == "sine":
            v = math.sin(ph)
        elif kind == "tri":
            v = 2 / math.pi * math.asin(math.sin(ph))
        else:  # square-ish
            v = 1.0 if math.sin(ph) >= 0 else -1.0
        s.append(v * env[i])
    return s


def _noise(dur, attack=0.001, release=0.08, lp=0.0):
    """White noise with an optional one-pole low-pass (lp in 0..1, higher=darker)."""
    n = int(dur * SR)
    env = _env(n, attack, release)
    s = []
    prev = 0.0
    for i in range(n):
        w = random.uniform(-1, 1)
        if lp > 0:
            prev = prev + (1 - lp) * (w - prev)
            w = prev
        s.append(w * env[i])
    return s


def _sweep(f0, f1, dur, attack=0.002, release=0.06):
    n = int(dur * SR)
    env = _env(n, attack, release)
    s = []
    ph = 0.0
    for i in range(n):
        f = f0 + (f1 - f0) * (i / n)
        ph += 2 * math.pi * f / SR
        s.append(math.sin(ph) * env[i] * 0.6 + random.uniform(-1, 1) * env[i] * 0.4)
    return s


def _mix(*layers):
    n = max(len(x) for x in layers)
    out = [0.0] * n
    for x in layers:
        for i, v in enumerate(x):
            out[i] += v
    return out


def _normalise(s, peak=0.71):  # ~-3 dBFS
    m = max((abs(v) for v in s), default=1.0) or 1.0
    return [v / m * peak for v in s]


def recipe(cue):
    random.seed(cue)  # str seed is stable across runs (unlike hash())
    if cue == "uiTap":
        return _tone(1200, 0.05, release=0.04, kind="tri")
    if cue == "strikeDull":
        return _mix(_noise(0.16, release=0.14, lp=0.86), _tone(140, 0.12, release=0.1))
    if cue == "strikeWeapon":
        return _mix(_noise(0.09, release=0.07, lp=0.35), _tone(2400, 0.07, release=0.06, kind="tri"))
    if cue == "strikeTechnique":
        return _mix(_sweep(600, 1500, 0.26), _tone(300, 0.22, release=0.2))
    if cue == "strikePerfect":
        return _mix(_tone(1760, 0.3, release=0.26), _tone(2640, 0.3, release=0.24))
    if cue == "strikeMiss":
        return _sweep(1400, 300, 0.3, release=0.12)
    if cue == "guardHold":
        return _mix(_noise(0.08, release=0.06, lp=0.6), _tone(520, 0.09, release=0.07, kind="tri"))
    if cue == "bodyBlow":
        return _mix(_noise(0.2, release=0.18, lp=0.9), _tone(90, 0.18, release=0.16))
    if cue == "waveStart":
        return _tone(880, 0.12, release=0.1, kind="tri")
    if cue == "sessionEnd":
        return _mix(_tone(587, 0.34, release=0.3), _tone(880, 0.34, release=0.28))
    if cue == "techniqueEvolved":
        return _mix(_tone(523, 0.5, release=0.44), _tone(784, 0.5, release=0.42),
                    _tone(1046, 0.5, release=0.4))
    if cue == "fightWon":
        return _mix(_tone(523, 0.45, release=0.4), _tone(659, 0.45, release=0.38),
                    _tone(784, 0.45, glide=0.06, release=0.36))
    if cue == "fightLost":
        return _mix(_tone(196, 0.6, release=0.55), _noise(0.5, release=0.42, lp=0.92))
    raise ValueError(cue)


def write_wav(path, samples):
    samples = _normalise(samples)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", max(-32768, min(32767, int(v * 32767)))) for v in samples
        ))


def main():
    os.makedirs(OUT, exist_ok=True)
    have_ffmpeg = shutil.which("ffmpeg") is not None
    for cue in CUES:
        wav = os.path.join(OUT, cue + ".wav")
        write_wav(wav, recipe(cue))
        if have_ffmpeg:
            ogg = os.path.join(OUT, cue + ".ogg")
            subprocess.run(
                ["ffmpeg", "-y", "-loglevel", "error", "-fflags", "+bitexact",
                 "-i", wav, "-map_metadata", "-1", "-fflags", "+bitexact",
                 "-q:a", "3", ogg],
                check=True,
            )
            os.remove(wav)
    ext = "ogg" if have_ffmpeg else "wav"
    total = sum(
        os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT) if f.endswith(ext)
    )
    print(f"wrote {len(CUES)} .{ext} files, {total // 1024} KiB total, in {OUT}")


if __name__ == "__main__":
    main()
