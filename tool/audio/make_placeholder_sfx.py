"""Synthesise JinHop's placeholder sounds (original, CC0 by the author).

  python3 tool/audio/make_placeholder_sfx.py   (needs numpy, scipy, ffmpeg)

Writes assets/audio/*.ogg. Replace any file with a CC0 recording of the same
name; nothing else needs to change.
"""
import os, subprocess, tempfile
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'audio')
rng = np.random.default_rng(7)

def env(n, a=0.01, r=0.3):
    t = np.linspace(0, 1, n)
    e = np.minimum(1, t / max(a, 1e-4)) * np.exp(-t / r)
    return e

def lp(x, hz, order=2):
    b, a = butter(order, hz / (SR / 2), 'low'); return lfilter(b, a, x)

def bp(x, lo, hi):
    b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], 'band'); return lfilter(b, a, x)

def save(name, x, gain=0.8):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    fd, wav = tempfile.mkstemp(suffix='.wav'); os.close(fd)
    wavfile.write(wav, SR, (x * 32767).astype(np.int16))
    os.makedirs(OUT, exist_ok=True)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-ac', '1', '-c:a', 'libvorbis', '-q:a', '4',
                    os.path.join(OUT, name + '.ogg')], check=True)
    os.remove(wav)

def croak():
    # Two soft "rib-bit" pulses: a pulsed low tone through a vocal-ish band.
    d = 0.32; n = int(SR * d); t = np.arange(n) / SR
    f0 = 140 + 30 * np.exp(-t * 12)
    saw = 2 * ((np.cumsum(f0) / SR) % 1) - 1
    pulses = (np.sin(2 * np.pi * 38 * t) > -0.2).astype(float)
    x = bp(saw * pulses, 250, 1400) * env(n, 0.02, 0.12)
    gap = np.zeros(int(SR * 0.06))
    x2 = np.concatenate([x[: int(n * 0.45)], gap, x[: int(n * 0.6)] * 0.8])
    return lp(x2, 2200)

def splash():
    n = int(SR * 0.45); t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    sweep = bp(noise, 600, 3500) * env(n, 0.005, 0.08)
    drops = np.zeros(n)
    for k in range(6):
        s = int(SR * (0.04 + 0.05 * k + rng.uniform(0, 0.02)))
        f = rng.uniform(900, 1700); L = int(SR * 0.05)
        tt = np.arange(L) / SR
        drops[s:s + L] += np.sin(2 * np.pi * f * (1 + 3 * tt) * tt) * np.exp(-tt * 70) * 0.5
    return lp(sweep + drops, 5000)

def shake():
    # Soft wooden thud: low sine with quick pitch drop, no harshness.
    n = int(SR * 0.22); t = np.arange(n) / SR
    f = 110 * np.exp(-t * 6) + 60
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(n, 0.003, 0.05)
    x += lp(rng.standard_normal(n), 400) * env(n, 0.001, 0.015) * 0.6
    return lp(x, 900)

def bell(f, dur, amp=1.0):
    n = int(SR * dur); t = np.arange(n) / SR
    x = (np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 6)
         + 0.2 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 9))
    return x * env(n, 0.004, dur * 0.35) * amp

def bloom():
    # Rising pentatonic chime (G major pentatonic), gentle.
    notes = [392.0, 440.0, 493.9, 587.3, 659.3, 784.0]
    out = np.zeros(int(SR * 1.8))
    for i, f in enumerate(notes):
        b = bell(f, 1.2, 0.8 - i * 0.06); s = int(SR * 0.09 * i)
        out[s:s + len(b)] += b[: len(out) - s]
    return lp(out, 6000)

def ambient():
    # 32 s seamless loop: soft drone pad in D + filtered water + rare far chimes.
    d = 32.0; n = int(SR * d); t = np.arange(n) / SR
    pad = np.zeros(n)
    for f, a in [(146.8, 1.0), (220.0, 0.6), (293.7, 0.45), (440.0, 0.15)]:
        lfo = 1 + 0.003 * np.sin(2 * np.pi * t / d * 2)
        pad += a * np.sin(2 * np.pi * f * lfo * t)
    pad *= 0.55 + 0.45 * np.sin(2 * np.pi * t / d * 4) ** 2  # breathing, period divides the loop
    water = lp(rng.standard_normal(n), 700) * (0.5 + 0.5 * np.sin(2 * np.pi * t / d * 3) ** 2)
    x = pad * 0.5 + water * 0.9
    for s_sec, f in [(5.0, 587.3), (13.5, 659.3), (21.0, 493.9), (27.5, 784.0)]:
        b = bell(f, 2.5, 0.12); s = int(SR * s_sec); x[s:s + len(b)] += b
    # Crossfade the tail into the head so the loop has no click.
    fade = int(SR * 1.0); w = np.linspace(0, 1, fade)
    x[:fade] = x[:fade] * w + x[-fade:] * (1 - w)
    return x[: n - fade]

save('croak', croak()); save('splash', splash(), 0.6); save('shake', shake(), 0.7)
save('bloom', bloom(), 0.7); save('ambient_loop', ambient(), 0.5)
print('ok')
