# Reference: recording -> CLAP model input

`clap_features.py` turns a mono 48 kHz recording into the `input_features` the ONNX model takes
([1, 1, 1001, 64], float32). It is plain NumPy, written step by step so it can be ported to Dart or Swift.
The steps are listed at the top of the file.

`make_fixtures.py` checks it against the official transformers `ClapFeatureExtractor` and writes `fixtures/`.

## Fixtures (for testing an app port)

All `.bin` files are raw little-endian float32, row-major.

| File | Shape | What |
|---|---|---|
| `mel_filters_513x64.f32.bin` | 513 x 64 | The mel filter bank. An app can load this as an asset instead of rebuilding it |
| `short_tone.features.f32.bin` | 1 x 1 x 1001 x 64 | Expected output for the `short_tone` test signal (1.5 s, repeat-padded) |
| `chirp_10s.features.f32.bin` | 1 x 1 x 1001 x 64 | Expected output for `chirp_10s` (exactly 10 s) |
| `long_12s.features.f32.bin` | 1 x 1 x 1001 x 64 | Expected output for `long_12s` (cut to the first 10 s) |
| `summary.json` | | Match against transformers, plus a few spot values per signal |

The test signals are simple formulas (see `test_signal` in `clap_features.py`), so a port regenerates them
exactly and compares its output with the `.bin` file. A port passes if the largest difference is under 0.01 dB.

Regenerate: `pip install numpy transformers torch`, then `python ml/reference/make_fixtures.py`.
