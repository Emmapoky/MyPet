"""Plain NumPy reference for the CLAP audio input (MyPet step 2b).

Turns a mono 48 kHz recording into the `input_features` array that the
Xenova/clap-htsat-unfused ONNX audio model expects: float32, shape
[1, 1, 1001, 64]. Written step by step, with no librosa or transformers,
so it can be ported line by line to Dart (Flutter) or Swift.

It reproduces transformers' ClapFeatureExtractor for this model
(truncation "rand_trunc", padding "repeatpad", Slaney mel filters), with one
deliberate change: a recording longer than 10 s is cut to its FIRST 10 s
instead of a random 10 s, so the app gives the same answer every time.

Steps
1. Length: exactly 480,000 samples (10 s at 48 kHz).
   Shorter: repeat the whole clip as many full times as fit, then pad zeros.
   Longer: keep the first 480,000 samples.
2. Pad 512 samples at each end by mirror reflection (centred frames).
3. Frames: 1024 samples, hop 480 -> 1001 frames. Multiply by a periodic Hann window.
4. Power spectrum: |FFT|^2 of each frame, first 513 bins.
5. Mel: multiply by a 513 x 64 Slaney mel filter bank (50 Hz to 14 kHz). Floor at 1e-10.
6. Decibels: 10 * log10(value).
7. Shape [1001, 64] -> [1, 1, 1001, 64], float32.
"""
import numpy as np

SR = 48_000
N_SAMPLES = 480_000      # 10 s
N_FFT = 1024
HOP = 480
N_MELS = 64
F_MIN, F_MAX = 50.0, 14_000.0
N_FRAMES = 1 + N_SAMPLES // HOP   # 1001


def fix_length(x: np.ndarray) -> np.ndarray:
    x = np.asarray(x, dtype=np.float64)
    if len(x) >= N_SAMPLES:
        return x[:N_SAMPLES]
    x = np.tile(x, N_SAMPLES // len(x))
    return np.pad(x, (0, N_SAMPLES - len(x)))


def hz_to_mel(f):   # Slaney: linear below 1 kHz, log above
    f = np.asarray(f, dtype=np.float64)
    m = 3.0 * f / 200.0
    log_part = 15.0 + np.log(np.maximum(f, 1e-10) / 1000.0) * (27.0 / np.log(6.4))
    return np.where(f >= 1000.0, log_part, m)


def mel_to_hz(m):
    m = np.asarray(m, dtype=np.float64)
    f = 200.0 * m / 3.0
    log_part = 1000.0 * np.exp(np.log(6.4) / 27.0 * (m - 15.0))
    return np.where(m >= 15.0, log_part, f)


def mel_filter_bank() -> np.ndarray:
    """513 x 64 triangular filters with Slaney area normalisation."""
    fft_freqs = np.linspace(0, SR // 2, N_FFT // 2 + 1)
    mel_pts = np.linspace(hz_to_mel(F_MIN), hz_to_mel(F_MAX), N_MELS + 2)
    hz_pts = mel_to_hz(mel_pts)
    fb = np.zeros((len(fft_freqs), N_MELS))
    for i in range(N_MELS):
        lo, mid, hi = hz_pts[i], hz_pts[i + 1], hz_pts[i + 2]
        up = (fft_freqs - lo) / (mid - lo)
        down = (hi - fft_freqs) / (hi - mid)
        fb[:, i] = np.maximum(0.0, np.minimum(up, down)) * (2.0 / (hi - lo))
    return fb


def hann_periodic(n: int) -> np.ndarray:
    return 0.5 - 0.5 * np.cos(2.0 * np.pi * np.arange(n) / n)


def clap_input_features(x: np.ndarray, fb: np.ndarray | None = None) -> np.ndarray:
    fb = mel_filter_bank() if fb is None else fb
    x = fix_length(x)
    x = np.pad(x, (N_FFT // 2, N_FFT // 2), mode="reflect")
    win = hann_periodic(N_FFT)
    out = np.empty((N_FRAMES, N_MELS))
    for t in range(N_FRAMES):
        frame = x[t * HOP: t * HOP + N_FFT] * win
        power = np.abs(np.fft.rfft(frame)) ** 2          # 513 bins
        mel = np.maximum(1e-10, power @ fb)               # 64 values
        out[t] = 10.0 * np.log10(mel)
    return out.astype(np.float32)[None, None]          # [1, 1, 1001, 64]


# Test signals any port can regenerate exactly from these formulas
def test_signal(name: str) -> np.ndarray:
    if name == "short_tone":      # 1.5 s, 440 Hz + 1 kHz: exercises repeat-padding
        t = np.arange(int(1.5 * SR)) / SR
        return 0.5 * np.sin(2 * np.pi * 440 * t) + 0.25 * np.sin(2 * np.pi * 1000 * t)
    if name == "chirp_10s":       # exactly 10 s, 100 Hz -> 12 kHz sweep
        t = np.arange(N_SAMPLES) / SR
        return 0.3 * np.sin(2 * np.pi * (100 * t + (12000 - 100) / (2 * 10) * t ** 2))
    if name == "long_12s":        # 12 s, two tones: exercises cutting to the first 10 s
        t = np.arange(12 * SR) / SR
        return 0.4 * np.sin(2 * np.pi * 300 * t) * (t < 6) + 0.4 * np.sin(2 * np.pi * 2500 * t) * (t >= 6)
    raise ValueError(name)


TEST_SIGNALS = ["short_tone", "chirp_10s", "long_12s"]
