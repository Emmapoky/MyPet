"""Check the reference against transformers and write fixtures for app ports.

Run: python ml/reference/make_fixtures.py   (needs numpy and transformers, no PyTorch)
Writes ml/reference/fixtures/: the mel filter bank and the expected features
for each test signal, as little-endian float32 .bin files, plus summary.json.
"""
import json, os, sys
import numpy as np
from transformers import ClapFeatureExtractor
sys.path.insert(0, os.path.dirname(__file__))
from clap_features import *

out_dir = os.path.join(os.path.dirname(__file__), "fixtures")
os.makedirs(out_dir, exist_ok=True)

# Settings of laion/clap-htsat-unfused (Xenova ships the same; checked in step 2)
hf = ClapFeatureExtractor(feature_size=64, sampling_rate=48000, hop_length=480, max_length_s=10,
                          fft_window_size=1024, frequency_min=50, frequency_max=14000,
                          truncation="rand_trunc", padding="repeatpad")
fb = mel_filter_bank()
summary = {"mel_filter_bank_max_abs_diff_vs_transformers": float(np.abs(fb - hf.mel_filters_slaney).max())}
fb.astype("<f4").tofile(os.path.join(out_dir, "mel_filters_513x64.f32.bin"))

for name in TEST_SIGNALS:
    x = test_signal(name)
    ours = clap_input_features(x, fb)
    x_hf = x[:N_SAMPLES] if len(x) > N_SAMPLES else x   # our deterministic cut; HF would crop randomly
    theirs = hf(x_hf, sampling_rate=SR, return_tensors="np")["input_features"].astype(np.float32)
    d = np.abs(ours - theirs)
    ours.astype("<f4").tofile(os.path.join(out_dir, f"{name}.features.f32.bin"))
    summary[name] = {"samples": int(len(x)), "shape": list(ours.shape),
                     "max_abs_diff_db_vs_transformers": round(float(d.max()), 6),
                     "mean": round(float(ours.mean()), 4), "min": round(float(ours.min()), 4), "max": round(float(ours.max()), 4),
                     "frame0_first5": [round(float(v), 4) for v in ours[0, 0, 0, :5]],
                     "frame500_first5": [round(float(v), 4) for v in ours[0, 0, 500, :5]]}
json.dump(summary, open(os.path.join(out_dir, "summary.json"), "w"), indent=1)
print(json.dumps(summary, indent=1))
ok = summary["mel_filter_bank_max_abs_diff_vs_transformers"] < 1e-6 and all(summary[n]["max_abs_diff_db_vs_transformers"] < 1e-3 for n in TEST_SIGNALS)
print("MATCH" if ok else "MISMATCH")
sys.exit(0 if ok else 1)
