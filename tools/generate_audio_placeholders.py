#!/usr/bin/env python3
"""Generate the M5 placeholder audio set (spec §9.9).

The launch build needs a distinct, audible sound for every event before real
audio exists. This script synthesises short 16-bit mono 44.1 kHz WAV files:

  assets/audio/music/  menu_theme.wav, battle_theme.wav, boss_theme.wav  (20 s loops)
  assets/audio/ui/     seven interface sounds (80-220 ms)
  assets/audio/battle/ eighteen battle sounds (80-250 ms)
  assets/audio/meta/   five meta progression sounds

Music is generated as 20-second seamless loops (the brief's placeholder length);
the final assets will be 60/90 s OGG tracks (spec §9.9). Run:

  python tools/generate_audio_placeholders.py
"""
from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

import numpy as np

RATE = 44100
ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "assets" / "audio"
rng = np.random.default_rng(20261031)


# --- helpers -------------------------------------------------------------------

def _envelope(n: int, attack: float = 0.005, release: float = 0.05) -> np.ndarray:
    env = np.ones(n, dtype=np.float64)
    a = max(1, int(attack * RATE))
    r = max(1, int(release * RATE))
    a = min(a, n)
    r = min(r, n)
    env[:a] = np.linspace(0.0, 1.0, a)
    env[n - r:] *= np.linspace(1.0, 0.0, r)
    return env


def _tone(freq: float, seconds: float, amp: float = 0.5, wave_type: str = "sine") -> np.ndarray:
    n = max(1, int(seconds * RATE))
    t = np.arange(n) / RATE
    phase = 2.0 * math.pi * freq * t
    if wave_type == "square":
        signal = np.sign(np.sin(phase)) * 0.6
    elif wave_type == "saw":
        signal = 2.0 * ((freq * t) % 1.0) - 1.0
    elif wave_type == "triangle":
        signal = 2.0 * np.abs(2.0 * ((freq * t) % 1.0) - 1.0) - 1.0
    else:
        signal = np.sin(phase)
    return signal * amp * _envelope(n)


def _noise(seconds: float, amp: float = 0.4, lowpass: float = 0.3) -> np.ndarray:
    n = max(1, int(seconds * RATE))
    signal = rng.normal(0.0, 1.0, n)
    # one-pole low-pass; lowpass=0 is raw noise, 1 is silence
    out = np.empty(n)
    value = 0.0
    for index in range(n):
        value += (1.0 - lowpass) * (signal[index] - value)
        out[index] = value
    return out * amp * _envelope(n)


def _mix(*parts: np.ndarray) -> np.ndarray:
    length = max(len(part) for part in parts)
    out = np.zeros(length)
    for part in parts:
        out[:len(part)] += part
    return out


def _save(relative: str, samples: np.ndarray) -> None:
    peak = float(np.max(np.abs(samples))) if len(samples) else 0.0
    if peak > 0.95:
        samples = samples * (0.95 / peak)
    data = np.clip(samples, -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    path = AUDIO / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())
    print("wrote %-34s %6.2f s  %6.1f KB" % (relative, len(pcm) / RATE, path.stat().st_size / 1024))


def _sweep(start: float, end: float, seconds: float, amp: float = 0.5) -> np.ndarray:
    n = max(1, int(seconds * RATE))
    t = np.arange(n) / RATE
    freq = np.linspace(start, end, n)
    phase = 2.0 * math.pi * np.cumsum(freq) / RATE
    return np.sin(phase) * amp * _envelope(n, 0.004, 0.06)


def _pluck(freq: float, seconds: float, amp: float = 0.45) -> np.ndarray:
    n = max(1, int(seconds * RATE))
    t = np.arange(n) / RATE
    signal = np.sin(2 * math.pi * freq * t) + 0.4 * np.sin(4 * math.pi * freq * t)
    signal += 0.2 * np.sin(6 * math.pi * freq * t)
    decay = np.exp(-t * 9.0)
    return signal * amp * decay * _envelope(n, 0.002, 0.02)


# --- music loops ---------------------------------------------------------------

def _music_loop(seconds: float, root: float, scale: list[int], bpm: float, bright: float) -> np.ndarray:
    n = int(seconds * RATE)
    out = np.zeros(n)
    beat = 60.0 / bpm
    step = beat / 2.0
    note_count = int(seconds / step)
    for index in range(note_count):
        degree = scale[(index * 3 + index // 4) % len(scale)]
        freq = root * (2.0 ** (degree / 12.0))
        start = int(index * step * RATE)
        length = int(step * RATE * 2.2)
        if start >= n:
            break
        length = min(length, n - start)
        t = np.arange(length) / RATE
        partial = (
            np.sin(2 * math.pi * freq * t)
            + bright * 0.35 * np.sin(4 * math.pi * freq * t)
            + bright * 0.12 * np.sin(6 * math.pi * freq * t)
        )
        pad = partial * np.exp(-t * 1.2) * 0.16
        out[start:start + length] += pad
        # bass on every other step
        if index % 4 == 0:
            bass_freq = root / 2.0
            bass = np.sin(2 * math.pi * bass_freq * t) * np.exp(-t * 2.0) * 0.12
            out[start:start + length] += bass[:length]
    # soft global loop envelope keeps the seam click-free
    fade = min(int(0.25 * RATE), n // 4)
    out[:fade] *= np.linspace(0.0, 1.0, fade)
    out[-fade:] *= np.linspace(1.0, 0.0, fade)
    return out


# --- SFX catalogue -------------------------------------------------------------

def build() -> None:
    # music: 20 s loops, distinct modes/tempos
    _save("music/menu_theme.wav", _music_loop(20.0, 220.0, [0, 3, 5, 7, 10, 12, 15], 84.0, 0.6))
    _save("music/battle_theme.wav", _music_loop(20.0, 146.83, [0, 2, 3, 7, 8, 12, 14], 116.0, 1.0))
    _save("music/boss_theme.wav", _music_loop(20.0, 110.0, [0, 1, 5, 6, 7, 11, 12], 132.0, 1.2))

    # UI
    _save("ui/ui_click.wav", _mix(_tone(880, 0.06, 0.35), _noise(0.03, 0.08, 0.6)))
    _save("ui/ui_back.wav", _sweep(660, 440, 0.12, 0.4))
    _save("ui/ui_toggle.wav", _mix(_tone(520, 0.05, 0.3), _tone(780, 0.07, 0.3)))
    _save("ui/ui_error.wav", _mix(_tone(180, 0.16, 0.4, "square"), _tone(140, 0.16, 0.3, "square")))
    _save("ui/ui_purchase.wav", _mix(*[_pluck(f, 0.12, 0.35) for f in (880, 1174.66, 1567.98)]))
    _save("ui/ui_claim.wav", _mix(*[_pluck(f, 0.16, 0.32) for f in (659.25, 830.61, 987.77, 1318.51)]))
    _save("ui/card_flip.wav", _mix(_noise(0.14, 0.22, 0.25), _sweep(1200, 2400, 0.12, 0.18)))

    # battle
    _save("battle/wave_start.wav", _mix(_sweep(180, 420, 0.24, 0.35), _tone(220, 0.18, 0.2, "saw")))
    _save("battle/wave_clear.wav", _mix(*[_pluck(f, 0.22, 0.3) for f in (523.25, 659.25, 783.99)]))
    _save("battle/boss_roar.wav", _mix(_sweep(110, 55, 0.25, 0.5), _noise(0.25, 0.3, 0.55)))
    _save("battle/tree_hurt.wav", _mix(_tone(90, 0.2, 0.5), _noise(0.12, 0.2, 0.5)))
    _save("battle/enemy_leak.wav", _mix(_tone(740, 0.1, 0.3, "square"), _tone(560, 0.14, 0.3, "square")))
    _save("battle/enemy_die.wav", _mix(_noise(0.16, 0.35, 0.35), _sweep(320, 120, 0.16, 0.2)))
    _save("battle/hit_flesh.wav", _noise(0.09, 0.4, 0.4))
    _save("battle/hit_armor.wav", _mix(_tone(1500, 0.07, 0.3), _tone(2100, 0.05, 0.2)))
    _save("battle/crit.wav", _mix(_tone(1760, 0.1, 0.35), _tone(2640, 0.08, 0.25)))
    _save("battle/shoot_arrow.wav", _mix(_noise(0.07, 0.25, 0.15), _sweep(1500, 900, 0.06, 0.2)))
    _save("battle/shoot_cannon.wav", _mix(_sweep(160, 60, 0.22, 0.5), _noise(0.14, 0.25, 0.55)))
    _save("battle/shoot_frost.wav", _mix(*[_tone(f, 0.14, 0.22) for f in (1320, 1760, 2093)]))
    _save("battle/shoot_magic.wav", _mix(_sweep(600, 1800, 0.18, 0.28), _tone(900, 0.16, 0.18)))
    _save("battle/tower_build.wav", _mix(_tone(110, 0.12, 0.4), _noise(0.08, 0.3, 0.5)))
    _save("battle/tower_upgrade.wav", _mix(*[_pluck(f, 0.18, 0.28) for f in (440, 554.37, 659.25)]))
    _save("battle/tower_sell.wav", _mix(*[_pluck(f, 0.1, 0.3) for f in (987.77, 783.99, 659.25)]))
    _save("battle/upgrade_buy.wav", _mix(_pluck(659.25, 0.18, 0.3), _pluck(880, 0.22, 0.3)))
    _save("battle/run_defeat.wav", _mix(_sweep(330, 80, 0.25, 0.4), _tone(110, 0.22, 0.25, "triangle")))

    # meta
    _save("meta/research_start.wav", _sweep(300, 900, 0.22, 0.3))
    _save("meta/research_complete.wav", _mix(*[_pluck(f, 0.24, 0.28) for f in (523.25, 783.99, 1046.5)]))
    _save("meta/coin_gain.wav", _mix(*[_pluck(f, 0.1, 0.3) for f in (1318.51, 1760)]))
    _save("meta/gem_gain.wav", _mix(*[_tone(f, 0.16, 0.25) for f in (1567.98, 2093.0, 2637.02)]))
    _save("meta/level_up.wav", _mix(*[_pluck(f, 0.2, 0.3) for f in (523.25, 659.25, 783.99, 1046.5)]))


if __name__ == "__main__":
    build()
