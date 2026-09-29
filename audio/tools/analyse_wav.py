#!/usr/bin/env python3
"""Objective checks and a spectrogram for the sounds in audio/preview. Standard library only (no numpy).

    python audio/tools/analyse_wav.py FILE.wav [--png OUT.png] [--voice] [--max-hz 8000]

Prints: length, peak and RMS level, DC offset, clipped samples, the first and last sample (a click check), how long
the envelope takes to fall 20, 40 and 60 dB below its peak, the share of energy in octave-ish bands, and the spectral
centroid. With --voice it also estimates the pitch (f0) at several times and the formant peaks (LPC envelope) in the
voiced part. With --png it draws a spectrogram: time runs left to right, frequency bottom to top, brighter = louder,
and a white tick on the left edge marks every 1 kHz.

This is a numerical check, not a listening test. It says whether a sound is the right size, shape and colour; it can
not say whether it sounds good. A person has to listen.
"""
import argparse
import cmath
import math
import struct
import sys
import wave
import zlib


def read_wav(path):
    with wave.open(path, "rb") as w:
        assert w.getsampwidth() == 2 and w.getnchannels() == 1, "expects 16-bit mono"
        rate = w.getframerate()
        raw = w.readframes(w.getnframes())
    n = len(raw) // 2
    return rate, [s / 32768.0 for s in struct.unpack("<%dh" % n, raw)]


def db(x):
    return 20.0 * math.log10(max(x, 1e-9))


def fft(a):
    """Iterative radix-2 FFT of a list of complex numbers (length a power of two)."""
    n = len(a)
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j ^= bit
        if i < j:
            a[i], a[j] = a[j], a[i]
    size = 2
    while size <= n:
        w_step = cmath.exp(-2j * math.pi / size)
        for start in range(0, n, size):
            w = 1.0
            half = size // 2
            for k in range(half):
                u = a[start + k]
                v = a[start + k + half] * w
                a[start + k] = u + v
                a[start + k + half] = u - v
                w *= w_step
        size <<= 1
    return a


def hann(n):
    return [0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1)) for i in range(n)]


def power_spectrum(x, rate, n=None):
    """Average power spectrum over Hann frames covering x. Returns (freqs, power)."""
    n = n or 2048
    win = hann(n)
    hop = n // 2
    acc = [0.0] * (n // 2 + 1)
    frames = 0
    pos = 0
    while pos < len(x):
        seg = x[pos:pos + n]
        seg = seg + [0.0] * (n - len(seg))
        buf = fft([complex(seg[i] * win[i], 0.0) for i in range(n)])
        for k in range(n // 2 + 1):
            acc[k] += abs(buf[k]) ** 2
        frames += 1
        pos += hop
    return [k * rate / n for k in range(n // 2 + 1)], [p / max(frames, 1) for p in acc]


def a_weight_power(f):
    """Power gain of the A-weighting curve at f Hz (a rough guide to how loud a band is heard)."""
    if f <= 0:
        return 0.0
    f2 = f * f
    ra = (12194.0 ** 2 * f2 * f2) / ((f2 + 20.6 ** 2) * math.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2)) * (f2 + 12194.0 ** 2))
    return ra * ra


def band_shares(freqs, power, weighted=False):
    edges = [0, 60, 120, 250, 500, 1000, 2000, 4000, 8000, 1e9]
    if weighted:
        power = [p * a_weight_power(f) for f, p in zip(freqs, power)]
    total = sum(power) or 1.0
    out = []
    for lo, hi in zip(edges, edges[1:]):
        share = sum(p for f, p in zip(freqs, power) if lo <= f < hi) / total
        out.append((lo, hi, share))
    return out


def envelope_times(x, rate):
    """Seconds from the peak until a 5 ms RMS envelope first falls 20, 40 and 60 dB below its peak."""
    win = max(1, int(0.005 * rate))
    env = []
    for i in range(0, len(x) - win, win):
        seg = x[i:i + win]
        env.append(math.sqrt(sum(s * s for s in seg) / win))
    if not env:
        return {}
    pk = max(env)
    ip = env.index(pk)
    out = {}
    for drop in (20, 40, 60):
        limit = pk * 10 ** (-drop / 20.0)
        t = None
        for j in range(ip, len(env)):
            if env[j] < limit:
                t = (j - ip) * win / rate
                break
        out[drop] = t
    out["peak_at"] = ip * win / rate
    return out


def f0_at(x, rate, t, span=0.04, lo=55.0, hi=420.0):
    i0 = int(t * rate)
    seg = x[i0:i0 + int(span * rate)]
    if len(seg) < int(rate / lo) * 2:
        return None
    mean = sum(seg) / len(seg)
    seg = [s - mean for s in seg]
    e0 = sum(s * s for s in seg) or 1.0
    best, best_lag = 0.0, None
    for lag in range(int(rate / hi), int(rate / lo) + 1):
        c = sum(seg[i] * seg[i + lag] for i in range(len(seg) - lag)) / e0
        if c > best:
            best, best_lag = c, lag
    if best_lag is None or best < 0.25:
        return None
    return rate / best_lag, best


def lpc_peaks(x, rate, t, span=0.05, order=None, lo=200.0, hi=4200.0):
    """Formant-like peaks of the LPC spectral envelope around time t."""
    i0 = int(t * rate)
    seg = x[i0:i0 + int(span * rate)]
    n = len(seg)
    if n < 64:
        return []
    order = order or (2 + int(rate / 1000))
    w = hann(n)
    seg = [seg[i] * w[i] for i in range(n)]
    seg = [seg[0]] + [seg[i] - 0.97 * seg[i - 1] for i in range(1, n)]
    r = [sum(seg[i] * seg[i + k] for i in range(n - k)) for k in range(order + 1)]
    if r[0] <= 0:
        return []
    r[0] *= 1.0001
    a = [1.0] + [0.0] * order
    err = r[0]
    for i in range(1, order + 1):
        acc = r[i] + sum(a[j] * r[i - j] for j in range(1, i))
        k = -acc / err
        new = a[:]
        for j in range(1, i):
            new[j] = a[j] + k * a[i - j]
        new[i] = k
        a = new
        err *= (1 - k * k)
        if err <= 0:
            break
    freqs = [lo + (hi - lo) * i / 400.0 for i in range(401)]
    env = []
    for f in freqs:
        z = cmath.exp(-2j * math.pi * f / rate)
        den = sum(a[j] * z ** j for j in range(order + 1))
        env.append(1.0 / max(abs(den), 1e-9))
    peaks = [(freqs[i], env[i]) for i in range(1, len(env) - 1) if env[i] > env[i - 1] and env[i] >= env[i + 1]]
    peaks.sort(key=lambda p: -p[1])
    top = sorted(peaks[:5], key=lambda p: p[0])
    return [round(f) for f, _ in top]


COLORS = [(0.0, (0, 0, 4)), (0.25, (60, 9, 101)), (0.5, (187, 55, 84)), (0.75, (249, 142, 8)), (1.0, (252, 255, 164))]


def colour(v):
    v = min(max(v, 0.0), 1.0)
    for (a, ca), (b, cb) in zip(COLORS, COLORS[1:]):
        if v <= b:
            t = (v - a) / (b - a)
            return tuple(int(ca[i] + (cb[i] - ca[i]) * t) for i in range(3))
    return COLORS[-1][1]


def spectrogram_png(x, rate, path, max_hz=8000.0, n=512, dyn_db=70.0, sx=1, sy=1):
    hop = n // 4
    win = hann(n)
    cols = []
    top_bin = min(n // 2, int(max_hz / (rate / n)))
    peak_db = -200.0
    pos = 0
    while pos + n <= len(x) or pos == 0:
        seg = x[pos:pos + n]
        seg = seg + [0.0] * (n - len(seg))
        buf = fft([complex(seg[i] * win[i], 0.0) for i in range(n)])
        col = [db(abs(buf[k]) / n) for k in range(top_bin)]
        peak_db = max(peak_db, max(col))
        cols.append(col)
        pos += hop
        if pos >= len(x):
            break
    height = top_bin
    width = len(cols)
    rows = []
    for y in range(height - 1, -1, -1):
        row = bytearray([0])
        for c in range(width):
            r, g, b = colour((cols[c][y] - (peak_db - dyn_db)) / dyn_db)
            row += bytes((r, g, b)) * sx
        # 1 kHz ticks on the left edge
        hz = y * rate / n
        if abs(hz - round(hz / 1000.0) * 1000.0) < rate / n / 2 and hz >= 500:
            for c in range(min(6, width) * sx):
                row[1 + c * 3:4 + c * 3] = b"\xff\xff\xff"
        rows.extend([bytes(row)] * sy)
    raw = b"".join(rows)
    width *= sx
    height *= sy

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    return width, height, hop / rate, rate / n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("wav")
    ap.add_argument("--png")
    ap.add_argument("--voice", action="store_true")
    ap.add_argument("--lpc-order", type=int, default=12)
    ap.add_argument("--max-hz", type=float, default=8000.0)
    ap.add_argument("--sx", type=int, default=1, help="repeat each spectrogram column this many times")
    ap.add_argument("--sy", type=int, default=1, help="repeat each spectrogram row this many times")
    a = ap.parse_args()
    rate, x = read_wav(a.wav)
    n = len(x)
    peak = max(abs(s) for s in x)
    rms = math.sqrt(sum(s * s for s in x) / n)
    print("file        %s" % a.wav)
    print("length      %d samples, %d Hz, %.3f s" % (n, rate, n / rate))
    print("peak        %.1f dBFS   rms %.1f dBFS   crest %.1f dB" % (db(peak), db(rms), db(peak) - db(rms)))
    print("dc offset   %.5f   clipped samples %d" % (sum(x) / n, sum(1 for s in x if abs(s) >= 0.9999)))
    print("first/last  %.5f / %.5f (near zero means no click at the ends)" % (x[0], x[-1]))
    env = envelope_times(x, rate)
    print("envelope    peak at %.3f s; -20 dB after %s s, -40 dB after %s s, -60 dB after %s s" % (
        env["peak_at"], *["%.3f" % env[d] if env[d] is not None else "never" for d in (20, 40, 60)]))
    freqs, power = power_spectrum(x, rate)
    cent = sum(f * p for f, p in zip(freqs, power)) / (sum(power) or 1.0)
    print("centroid    %.0f Hz" % cent)
    print("bands       " + "  ".join("%s-%s Hz %.0f%%" % (int(lo), "up" if hi > 1e8 else int(hi), s * 100)
                                   for lo, hi, s in band_shares(freqs, power)))
    print("bands, A-weighted (closer to what is heard)  " + "  ".join(
        "%s-%s Hz %.0f%%" % (int(lo), "up" if hi > 1e8 else int(hi), s * 100)
        for lo, hi, s in band_shares(freqs, power, weighted=True)))
    if a.voice:
        print("pitch f0    " + "  ".join(
            "%.2fs: %s" % (t, ("%.0f Hz (r=%.2f)" % r) if (r := f0_at(x, rate, t)) else "none")
            for t in (0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35) if t < n / rate - 0.05))
        print("formants    " + "  ".join(
            "%.2fs: %s" % (t, lpc_peaks(x, rate, t, order=a.lpc_order)) for t in (0.08, 0.14, 0.20, 0.26) if t < n / rate - 0.06))
    if a.png:
        w, h, dt, df = spectrogram_png(x, rate, a.png, a.max_hz, sx=a.sx, sy=a.sy)
        print("spectrogram %s  %dx%d px, %.1f ms per column, %.1f Hz per row" % (a.png, w, h, dt * 1000, df))


if __name__ == "__main__":
    sys.exit(main())
