#!/usr/bin/env python3
"""Deterministically synthesize Project Rest Two's original music and SFX.

The generator uses only Python's standard library and mathematical oscillators.
It does not read, sample, or transform any third-party audio.
"""

from __future__ import annotations

import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import wave


SAMPLE_RATE = 32_000
MASTER_SEED = 31_072_026
GENERATOR_VERSION = "1.0.0"
REPO_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_ROOT = REPO_ROOT / "resources" / "audio"
PEAK = 10 ** (-4.0 / 20.0)

SFX_SPECS = {
    "ui_confirm.wav": {
        "duration": 0.11,
        "profile": "ui_confirm",
        "cue_ids": ["ui_confirm"],
    },
    "page_transition.wav": {
        "duration": 0.32,
        "profile": "page_transition",
        "cue_ids": ["page_transition"],
    },
    "recipe_place.wav": {
        "duration": 0.22,
        "profile": "recipe_place",
        "cue_ids": ["recipe_place", "recipe_move"],
    },
    "recipe_rotate.wav": {
        "duration": 0.18,
        "profile": "recipe_rotate",
        "cue_ids": ["recipe_rotate"],
    },
    "action_rejected.wav": {
        "duration": 0.24,
        "profile": "action_rejected",
        "cue_ids": ["action_rejected"],
    },
    "battle_start.wav": {
        "duration": 0.72,
        "profile": "battle_start",
        "cue_ids": ["battle_start"],
    },
    "sale.wav": {
        "duration": 0.19,
        "profile": "sale",
        "cue_ids": ["sale"],
    },
    "relation_bonus.wav": {
        "duration": 0.42,
        "profile": "relation_bonus",
        "cue_ids": ["relation_bonus"],
    },
    "demand_success.wav": {
        "duration": 0.34,
        "profile": "demand_success",
        "cue_ids": ["demand_success"],
    },
    "demand_failure.wav": {
        "duration": 0.42,
        "profile": "demand_failure",
        "cue_ids": ["demand_failure"],
    },
    "victory.wav": {
        "duration": 1.20,
        "profile": "victory",
        "cue_ids": ["victory"],
    },
    "defeat.wav": {
        "duration": 1.05,
        "profile": "defeat",
        "cue_ids": ["defeat"],
    },
    "upgrade_unlock.wav": {
        "duration": 0.82,
        "profile": "upgrade_unlock",
        "cue_ids": ["upgrade_unlock", "research_unlock", "reward_claim"],
    },
}

MUSIC_SPECS = {
    "planning_loop.wav": {
        "profile": "planning",
        "bpm": 96,
        "bars": 16,
        "music_contexts": ["hub", "preparation", "upgrade", "research", "menu", "summary"],
    },
    "battle_loop.wav": {
        "profile": "battle",
        "bpm": 128,
        "bars": 16,
        "music_contexts": ["battle"],
    },
}


def midi(note: int) -> float:
    return 440.0 * (2.0 ** ((note - 69) / 12.0))


def new_buffer(duration: float) -> tuple[array, array]:
    count = int(round(duration * SAMPLE_RATE))
    return array("f", [0.0]) * count, array("f", [0.0]) * count


def _pan_gains(pan: float) -> tuple[float, float]:
    angle = (max(-1.0, min(1.0, pan)) + 1.0) * math.pi / 4.0
    return math.cos(angle), math.sin(angle)


def add_tone(
    left: array,
    right: array,
    *,
    start: float,
    duration: float,
    frequency: float,
    amplitude: float,
    attack: float = 0.008,
    release: float = 0.12,
    decay: float = 0.0,
    pan: float = 0.0,
    waveform: str = "sine",
    frequency_end: float | None = None,
    tremolo_hz: float = 0.0,
    phase: float = 0.0,
) -> None:
    start_index = max(0, int(round(start * SAMPLE_RATE)))
    count = max(1, int(round(duration * SAMPLE_RATE)))
    end_index = min(len(left), start_index + count)
    left_gain, right_gain = _pan_gains(pan)
    oscillator_phase = phase
    last_frequency = frequency
    target_frequency = frequency if frequency_end is None else frequency_end
    for index in range(start_index, end_index):
        local_index = index - start_index
        t = local_index / SAMPLE_RATE
        position = local_index / max(1, count - 1)
        current_frequency = frequency + (target_frequency - frequency) * position
        if local_index:
            oscillator_phase += math.tau * (last_frequency + current_frequency) * 0.5 / SAMPLE_RATE
        last_frequency = current_frequency
        attack_gain = min(1.0, t / max(attack, 1.0 / SAMPLE_RATE))
        remaining = max(0.0, duration - t)
        release_gain = min(1.0, remaining / max(release, 1.0 / SAMPLE_RATE))
        envelope = attack_gain * release_gain
        if decay > 0.0:
            envelope *= math.exp(-decay * t)
        if tremolo_hz > 0.0:
            envelope *= 0.78 + 0.22 * math.sin(math.tau * tremolo_hz * t)
        sine = math.sin(oscillator_phase)
        if waveform == "triangle":
            value = 2.0 / math.pi * math.asin(sine)
        elif waveform == "soft_square":
            value = math.tanh(1.8 * sine) / math.tanh(1.8)
        elif waveform == "bell":
            value = (
                sine
                + 0.35 * math.sin(oscillator_phase * 2.01)
                + 0.16 * math.sin(oscillator_phase * 3.98)
            ) / 1.51
        else:
            value = sine
        sample = value * amplitude * envelope
        left[index] += sample * left_gain
        right[index] += sample * right_gain


def add_noise(
    left: array,
    right: array,
    rng: random.Random,
    *,
    start: float,
    duration: float,
    amplitude: float,
    attack: float = 0.002,
    release: float = 0.08,
    decay: float = 0.0,
    pan: float = 0.0,
    low_pass: float = 0.18,
) -> None:
    start_index = max(0, int(round(start * SAMPLE_RATE)))
    count = max(1, int(round(duration * SAMPLE_RATE)))
    end_index = min(len(left), start_index + count)
    left_gain, right_gain = _pan_gains(pan)
    filtered = 0.0
    for index in range(start_index, end_index):
        local_index = index - start_index
        t = local_index / SAMPLE_RATE
        remaining = max(0.0, duration - t)
        attack_gain = min(1.0, t / max(attack, 1.0 / SAMPLE_RATE))
        release_gain = min(1.0, remaining / max(release, 1.0 / SAMPLE_RATE))
        filtered += low_pass * (rng.uniform(-1.0, 1.0) - filtered)
        envelope = attack_gain * release_gain
        if decay > 0.0:
            envelope *= math.exp(-decay * t)
        sample = filtered * amplitude * envelope
        left[index] += sample * left_gain
        right[index] += sample * right_gain


def add_chord(
    left: array,
    right: array,
    notes: list[int],
    *,
    start: float,
    duration: float,
    amplitude: float,
    pan_spread: float = 0.45,
    waveform: str = "sine",
) -> None:
    center = (len(notes) - 1) / 2.0
    for index, note in enumerate(notes):
        pan = (index - center) / max(center, 1.0) * pan_spread
        add_tone(
            left,
            right,
            start=start,
            duration=duration,
            frequency=midi(note),
            amplitude=amplitude / max(1, len(notes)),
            attack=0.08,
            release=min(0.32, duration * 0.35),
            pan=pan,
            waveform=waveform,
            tremolo_hz=0.33,
        )


def render_sfx(profile: str, duration: float, seed: int) -> tuple[array, array]:
    left, right = new_buffer(duration)
    rng = random.Random(seed)

    if profile == "ui_confirm":
        add_noise(left, right, rng, start=0.0, duration=0.025, amplitude=0.22, decay=65.0)
        for frequency, amplitude, pan in [(1320, 0.48, -0.12), (1980, 0.30, 0.14), (3140, 0.15, 0.0)]:
            add_tone(left, right, start=0.0, duration=duration, frequency=frequency,
                     amplitude=amplitude, decay=28.0, release=0.04, pan=pan, waveform="bell")
    elif profile == "page_transition":
        add_noise(left, right, rng, start=0.0, duration=0.24, amplitude=0.32,
                  attack=0.08, release=0.08, pan=-0.25, low_pass=0.08)
        add_tone(left, right, start=0.03, duration=0.27, frequency=390, frequency_end=920,
                 amplitude=0.28, attack=0.05, release=0.10, pan=0.18, waveform="triangle")
        add_tone(left, right, start=0.21, duration=0.11, frequency=1318,
                 amplitude=0.23, decay=14.0, pan=0.22, waveform="bell")
    elif profile == "recipe_place":
        add_noise(left, right, rng, start=0.0, duration=0.055, amplitude=0.34, decay=48.0)
        for note, amplitude in [(48, 0.42), (60, 0.25), (67, 0.14)]:
            add_tone(left, right, start=0.0, duration=duration, frequency=midi(note),
                     amplitude=amplitude, decay=13.0, release=0.07, waveform="triangle")
    elif profile == "recipe_rotate":
        add_tone(left, right, start=0.0, duration=duration, frequency=560, frequency_end=1320,
                 amplitude=0.38, decay=7.0, release=0.06, pan=-0.12, waveform="triangle")
        add_tone(left, right, start=0.095, duration=0.08, frequency=1760,
                 amplitude=0.20, decay=16.0, pan=0.18, waveform="bell")
    elif profile == "action_rejected":
        for offset, note in [(0.0, 47), (0.09, 45)]:
            add_tone(left, right, start=offset, duration=0.14, frequency=midi(note),
                     amplitude=0.42, decay=10.0, release=0.05, waveform="soft_square")
    elif profile == "battle_start":
        add_noise(left, right, rng, start=0.0, duration=0.28, amplitude=0.38,
                  attack=0.08, release=0.06, low_pass=0.10)
        for offset, note in [(0.06, 45), (0.20, 52), (0.34, 57), (0.48, 64)]:
            add_tone(left, right, start=offset, duration=0.22, frequency=midi(note),
                     amplitude=0.38, decay=5.0, release=0.08, waveform="triangle")
        add_tone(left, right, start=0.48, duration=0.24, frequency=midi(76),
                 amplitude=0.24, decay=5.0, waveform="bell")
    elif profile == "sale":
        add_noise(left, right, rng, start=0.0, duration=0.035, amplitude=0.24, decay=55.0)
        for offset, note, pan in [(0.0, 72, -0.15), (0.055, 79, 0.15)]:
            add_tone(left, right, start=offset, duration=0.13, frequency=midi(note),
                     amplitude=0.34, decay=12.0, release=0.04, pan=pan, waveform="bell")
    elif profile == "relation_bonus":
        for offset, note, pan in [(0.0, 72, -0.22), (0.08, 76, 0.0), (0.16, 79, 0.22), (0.23, 84, 0.0)]:
            add_tone(left, right, start=offset, duration=0.18, frequency=midi(note),
                     amplitude=0.30, decay=8.0, release=0.07, pan=pan, waveform="bell")
    elif profile == "demand_success":
        for offset, note in [(0.0, 67), (0.105, 74)]:
            add_tone(left, right, start=offset, duration=0.23, frequency=midi(note),
                     amplitude=0.38, decay=7.0, release=0.08, waveform="bell")
    elif profile == "demand_failure":
        add_noise(left, right, rng, start=0.0, duration=0.11, amplitude=0.20, decay=18.0)
        for note in [55, 58]:
            add_tone(left, right, start=0.0, duration=duration, frequency=midi(note),
                     frequency_end=midi(note - 2), amplitude=0.30, decay=3.5,
                     release=0.12, waveform="soft_square")
    elif profile == "victory":
        for offset, notes in [
            (0.0, [60, 64, 67]),
            (0.30, [65, 69, 72]),
            (0.60, [67, 71, 74, 79]),
        ]:
            add_chord(left, right, notes, start=offset, duration=0.55,
                      amplitude=0.78, waveform="bell")
        add_noise(left, right, rng, start=0.58, duration=0.50, amplitude=0.12,
                  attack=0.20, release=0.16, low_pass=0.07)
    elif profile == "defeat":
        for index, note in enumerate([64, 60, 57, 52]):
            add_tone(left, right, start=index * 0.18, duration=0.46, frequency=midi(note),
                     frequency_end=midi(note - 1), amplitude=0.32, decay=1.8,
                     release=0.18, pan=(-0.16 + index * 0.10), waveform="triangle")
        add_tone(left, right, start=0.36, duration=0.69, frequency=midi(40),
                 amplitude=0.28, decay=1.5, release=0.22, waveform="soft_square")
    elif profile == "upgrade_unlock":
        add_noise(left, right, rng, start=0.02, duration=0.38, amplitude=0.13,
                  attack=0.14, release=0.10, low_pass=0.06)
        for offset, note, pan in [(0.0, 60, -0.25), (0.12, 67, 0.20), (0.24, 72, -0.10), (0.38, 76, 0.18)]:
            add_tone(left, right, start=offset, duration=0.40, frequency=midi(note),
                     amplitude=0.34, decay=4.2, release=0.13, pan=pan, waveform="bell")
    else:
        raise ValueError(f"Unknown SFX profile: {profile}")
    return left, right


def render_planning_music(spec: dict, seed: int) -> tuple[array, array, float]:
    beat = 60.0 / spec["bpm"]
    bar = beat * 4.0
    duration = spec["bars"] * bar
    left, right = new_buffer(duration)
    rng = random.Random(seed)
    chords = [
        [60, 64, 67, 71],
        [57, 60, 64, 67],
        [53, 57, 60, 64],
        [55, 59, 62, 64],
    ]
    melody = [76, 79, 81, 79, 76, 74, 72, 74, 76, 79, 84, 81, 79, 76, 74, 71]

    for bar_index in range(spec["bars"]):
        chord = chords[bar_index % len(chords)]
        start = bar_index * bar
        add_chord(left, right, chord, start=start, duration=bar * 0.98,
                  amplitude=0.30, waveform="sine")
        add_tone(left, right, start=start, duration=bar * 0.82,
                 frequency=midi(chord[0] - 24), amplitude=0.16,
                 attack=0.03, release=0.28, waveform="triangle")
        arpeggio = chord + [chord[1] + 12, chord[2] + 12, chord[1] + 12, chord[0] + 12]
        for step, note in enumerate(arpeggio):
            note_start = start + step * beat / 2.0
            add_tone(left, right, start=note_start, duration=beat * 0.43,
                     frequency=midi(note), amplitude=0.16, decay=3.0,
                     release=0.08, pan=-0.35 + (step % 4) * 0.23, waveform="bell")
        if bar_index % 2 == 0:
            note = melody[bar_index]
            add_tone(left, right, start=start + beat * 2.25, duration=beat * 1.25,
                     frequency=midi(note), amplitude=0.14, decay=1.0,
                     release=0.18, pan=0.28, waveform="bell")
        for beat_index in range(4):
            add_noise(left, right, rng, start=start + beat_index * beat,
                      duration=0.055, amplitude=0.075 if beat_index in [1, 3] else 0.045,
                      decay=25.0, pan=0.34, low_pass=0.16)
    return left, right, duration


def render_battle_music(spec: dict, seed: int) -> tuple[array, array, float]:
    beat = 60.0 / spec["bpm"]
    bar = beat * 4.0
    duration = spec["bars"] * bar
    left, right = new_buffer(duration)
    rng = random.Random(seed)
    chords = [
        [57, 60, 64],
        [53, 57, 60],
        [60, 64, 67],
        [55, 59, 62],
    ]
    hook = [69, 72, 76, 72, 69, 72, 77, 76, 72, 76, 79, 76, 71, 74, 79, 74]

    for bar_index in range(spec["bars"]):
        chord = chords[bar_index % len(chords)]
        start = bar_index * bar
        add_chord(left, right, chord, start=start, duration=bar * 0.95,
                  amplitude=0.22, waveform="triangle")
        for step in range(8):
            note = chord[step % len(chord)] + (12 if step in [3, 6, 7] else 0)
            add_tone(left, right, start=start + step * beat / 2.0,
                     duration=beat * 0.34, frequency=midi(note),
                     amplitude=0.17, decay=5.0, release=0.055,
                     pan=-0.28 if step % 2 == 0 else 0.28, waveform="soft_square")
        for beat_index in range(4):
            bass_note = chord[0] - 24 if beat_index in [0, 2] else chord[0] - 12
            add_tone(left, right, start=start + beat_index * beat,
                     duration=beat * 0.55, frequency=midi(bass_note),
                     amplitude=0.21, decay=3.0, release=0.08, waveform="triangle")
            add_tone(left, right, start=start + beat_index * beat,
                     duration=0.11, frequency=82.0, frequency_end=48.0,
                     amplitude=0.26, decay=18.0, release=0.035, waveform="sine")
            if beat_index in [1, 3]:
                add_noise(left, right, rng, start=start + beat_index * beat,
                          duration=0.14, amplitude=0.24, decay=13.0,
                          pan=-0.08, low_pass=0.22)
            add_noise(left, right, rng, start=start + beat_index * beat + beat / 2.0,
                      duration=0.045, amplitude=0.10, decay=28.0,
                      pan=0.36, low_pass=0.35)
        if bar_index % 2 == 1:
            add_tone(left, right, start=start + beat * 2.0, duration=beat * 1.6,
                     frequency=midi(hook[bar_index]), amplitude=0.17,
                     decay=1.0, release=0.16, pan=0.25, waveform="bell")
    return left, right, duration


def normalize(left: array, right: array) -> None:
    maximum = max(
        max((abs(sample) for sample in left), default=0.0),
        max((abs(sample) for sample in right), default=0.0),
    )
    if maximum <= 0.0:
        return
    gain = PEAK / maximum
    for index in range(len(left)):
        left[index] *= gain
        right[index] *= gain


def write_wave(path: Path, left: array, right: array) -> None:
    normalize(left, right)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        frames = bytearray(len(left) * 4)
        offset = 0
        for left_sample, right_sample in zip(left, right):
            struct.pack_into(
                "<hh",
                frames,
                offset,
                int(max(-1.0, min(1.0, left_sample)) * 32767),
                int(max(-1.0, min(1.0, right_sample)) * 32767),
            )
            offset += 4
        output.writeframes(frames)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def generate(output_root: Path) -> dict:
    assets: list[dict] = []
    for index, (file_name, spec) in enumerate(SFX_SPECS.items()):
        seed = MASTER_SEED + index * 101
        left, right = render_sfx(spec["profile"], spec["duration"], seed)
        path = output_root / "sfx" / file_name
        write_wave(path, left, right)
        assets.append({
            "path": path.relative_to(REPO_ROOT).as_posix(),
            "kind": "sfx",
            "profile": spec["profile"],
            "cue_ids": spec["cue_ids"],
            "duration_ms": round(spec["duration"] * 1000),
            "seed": seed,
            "sha256": sha256(path),
        })

    for index, (file_name, spec) in enumerate(MUSIC_SPECS.items()):
        seed = MASTER_SEED + 10_000 + index * 101
        if spec["profile"] == "planning":
            left, right, duration = render_planning_music(spec, seed)
        else:
            left, right, duration = render_battle_music(spec, seed)
        path = output_root / "music" / file_name
        write_wave(path, left, right)
        assets.append({
            "path": path.relative_to(REPO_ROOT).as_posix(),
            "kind": "music",
            "profile": spec["profile"],
            "music_contexts": spec["music_contexts"],
            "duration_ms": round(duration * 1000),
            "bpm": spec["bpm"],
            "bars": spec["bars"],
            "seed": seed,
            "sha256": sha256(path),
        })

    manifest = {
        "generator": "tools/generate_audio.py",
        "generator_version": GENERATOR_VERSION,
        "master_seed": MASTER_SEED,
        "sample_rate_hz": SAMPLE_RATE,
        "channels": 2,
        "sample_format": "signed 16-bit PCM little-endian WAV",
        "third_party_samples": [],
        "assets": assets,
    }
    manifest_path = output_root / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output-root",
        type=Path,
        default=OUTPUT_ROOT,
        help="Output directory (defaults to resources/audio).",
    )
    args = parser.parse_args()
    manifest = generate(args.output_root.resolve())
    print(f"Generated {len(manifest['assets'])} original audio assets.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
