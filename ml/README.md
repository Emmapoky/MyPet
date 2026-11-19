# MyPet behaviour model: step-by-step spikes

Each step is one notebook that runs free on Google Colab (open it from GitHub in Colab, then Runtime > Run all).
Results are copied into `results/` and summarised here, so the team can check them and agree or disagree in Semester 1.

Rules these follow (Dr Yam, 18 Sep 2026; proposal report): machine learning, not generative AI; free; the clip never leaves the phone; likelihoods only, never a diagnosis.

| Step | Notebook | Status |
|---|---|---|
| 1 | `01_clap_catmeows_spike.ipynb`: CLAP zero-shot vs CLAP embeddings + logistic regression on CatMeows | Done 19 Nov 2026 |
| 2 | `02_onnx_matches_pytorch.ipynb`: the planned on-device ONNX files give the same embeddings and the same result as step 1 | Done 19 Nov 2026 |
| 2b | `reference/`: plain NumPy version of the model input, checked against transformers, plus test files for any app port | Done 19 Nov 2026 |
| 2c | `dart/clap_features`: Dart (Flutter) version of the model input, tested against the 2b test files | Done 19 Nov 2026 |
| 3 | `flutter/behaviour_bench`: run the whole check in Flutter on a real iPhone and time it | Done 19 Nov 2026 (iPhone); Android not yet, no Android SDK on the Mac |
| 4 | `04_clap_dogs_emotionalcanines.ipynb`: same test as step 1 on EmotionalCanines dog barks | Done 19 Nov 2026 |
| 5 | YAMNet comparison (only if needed) | Later |

## Step 1 result (CatMeows, 440 meows, 21 cats, 3 contexts)

Question: can CLAP tell *why* a cat meows (waiting for food, being brushed, isolated)? Chance for 3 classes is about 0.33 macro F1.

| Method | Macro F1 | Accuracy | Evaluated on |
|---|---|---|---|
| Always guess the biggest class | 0.19 | 0.40 | 4 test cats (94 clips) |
| CLAP zero-shot (text prompts) | 0.28 | 0.27 | 4 test cats |
| CLAP embeddings + logistic regression | 0.40 | 0.44 | 4 test cats |
| CLAP zero-shot | 0.34 | 0.34 | all 440 clips |
| **CLAP embeddings + logistic regression** | **0.49** | **0.54** | 7-fold, 3 unseen cats per fold (440 clips) |

Embedding one clip took 0.63 s on Colab's free CPU (a phone will differ; timed in a later step).

**What this means**

- CLAP zero-shot is at chance on this task. It mostly answers "food" for everything (see the confusion matrix in `results/01_catmeows.json`). Keep it only as the baseline the report promised, not as a label source.
- A small classifier on CLAP embeddings is clearly better than zero-shot (0.49 vs 0.34 macro F1 on cats it never saw), so the plan of embeddings + logistic regression holds up.
- It is still weak. Isolation meows are recognised best; food and brushing get mixed up. Every number here is on cats the model never saw, which is the fair test for new users.
- The test split has only 4 cats, so the single-split numbers jump around. The 7-fold number is the one to quote.
- CatMeows clips are 1 to 4 s (median 1.8 s) and were repeat-padded to 10 s. The app plans 10 s recordings, so real clips may hold several meows. Worth testing once we record our own.

## Step 2 result (does the phone's ONNX file match?)

Same 440 clips, same input features fed to both. Xenova ships the same preprocessing settings as the original model (no differences).

| Model | Size | Cosine similarity to PyTorch (min / mean) | Macro F1 (7-fold by cat) | Time per clip, Colab CPU |
|---|---|---|---|---|
| PyTorch (step 1) | | | 0.49 | 0.63 s |
| `onnx/audio_model.onnx` | 117.5 MB | 1.000 / 1.000 | 0.49 | 0.29 s |
| `onnx/audio_model_quantized.onnx` | 34.3 MB | 0.992 / 0.998 | 0.50 | 0.27 s |

**What this means**

- The ONNX files are a faithful copy of the model. The full file is identical; the quantized one is within 1% and scores the same (0.50 vs 0.49 is noise).
- Use the **quantized 34.3 MB file** in the app: a quarter of the size, same result.
- ONNX in: `input_features`, float, shape [1, 1, 1001, 64] for one 10 s clip (48 kHz, FFT 1024, hop 480, 64 mel bins from 50 Hz, repeat-padded). ONNX out: `audio_embeds`, 512 numbers. The classifier then runs on those 512 numbers.
- The model itself is no longer a risk. The open risk is step 2b: the app must compute those 1001 x 64 features exactly like Python does (in Swift or Dart), or the embeddings will drift. The CLAP vs YAMNet decision hangs on that.

## Step 2b result (turning a recording into the model input)

`reference/clap_features.py` does it in seven plain steps with NumPy only (fix length to 10 s, mirror-pad, 1001 Hann-windowed frames, power spectrum, 64 Slaney mel filters, decibels). It matches transformers' `ClapFeatureExtractor` to within 0.00001 dB on all three test signals, and the mel filter bank matches exactly.

One deliberate difference: transformers takes a *random* 10 s from a longer clip; ours takes the *first* 10 s, so the app gives the same answer for the same recording.

`reference/fixtures/` holds the filter bank and the expected output for three test signals, so the Dart (or Swift) version can be checked number by number. Details in `reference/README.md`.

## Step 2c result (Dart version)

`dart/clap_features` is a line-by-line Dart port with no packages (own FFT). `dart test` checks it against the 2b fixtures: the filter bank matches within 1e-9 and the features within 0.00001 dB on all three test signals (pass mark 0.01 dB). One clip takes about 0.15 s on a laptop CPU; a phone will be slower and is timed in step 3.

This closes the feature-matching risk in the report: the app can compute the model input exactly. The CLAP or YAMNet decision now rests on phone speed and size (step 3).

## Step 3 result (real iPhone, 19 Nov 2026)

Erwyna's iPhone (iOS 27.2.1), Flutter app `flutter/behaviour_bench`, quantized CLAP ONNX via `flutter_onnxruntime`, Dart features in an isolate.

| Test sound | Clip to embedding (median) | Features | Model | First run | Matches Python (cosine) |
|---|---|---|---|---|---|
| short_tone (1.5 s, repeat-padded) | 103 ms | 51 ms | 51 ms | 103 ms | 1.0 |
| chirp_10s | 111 ms | 62 ms | 49 ms | 113 ms | 1.0 |
| long_12s (cut to 10 s) | 119 ms | 65 ms | 56 ms | 115 ms | 1.0 |

Loading the model once takes 456 ms (do it when the Check screen opens, not after recording).

**What this means:** the report's target of a result within 5 s (FR20, NFR03) is met with a wide margin, about 0.1 s, fully offline on the phone, and the phone's numbers match Python exactly. The classifier on top (logistic regression on 512 numbers) adds well under a millisecond. CLAP stays the plan; YAMNet is not needed for speed. Still to time: an Android phone, and an older iPhone.

**Honest wording for the app and report:** show likelihoods with "not a diagnosis", and say the behaviour check is an early estimate. This matches Dr Yam's line that logging is the minimum and AI is the best case.

## Step 4 result (dogs: EmotionalCanines, 1,400 barks, Husky and Shiba Inu)

Two labels per bark, three levels each: arousal (Low, Medium, High) and valence (Negative, Neutral, Positive). Tested on the dataset's own test set (100 barks per breed, from dogs not in the training set according to the dataset; it has no per-dog id we could check). Chance is about 0.33 macro F1.

| Task | Breed | Always guess biggest class | CLAP zero-shot | **CLAP + logistic regression** |
|---|---|---|---|---|
| Arousal | Husky | 0.17 | 0.32 | **0.43** |
| Arousal | Shiba | 0.17 | 0.38 | **0.59** |
| Arousal | Both (200 barks) | 0.17 | 0.35 | **0.54** |
| Valence | Husky | 0.17 | 0.18 | **0.45** |
| Valence | Shiba | 0.17 | 0.28 | **0.50** |
| Valence | Both (200 barks) | 0.17 | 0.23 | **0.48** |

All numbers are macro F1. Full numbers and confusion matrices: `results/04_dogs.json`.

**What this means**

- Same pattern as cats: zero-shot prompts are at or below chance (valence 0.23), while a small classifier on CLAP embeddings is clearly better (0.54 arousal, 0.48 valence). The plan of embeddings + logistic regression holds for dogs too.
- It is still weak, about one in two right on three levels. High-arousal and positive barks are spotted best; negative barks are often called neutral or positive (21 of 66 right). That is the case owners care about most, so the app must not sound sure about it.
- One model for both breeds does about as well as one per breed, so the app can start with one dog model. Two breeds is a narrow base; other breeds are untested.
- Barks are short (median 1 s) and were repeat-padded to 10 s, as with cats. A few clips are longer than 10 s (longest 30 s); for those, transformers took a random 10 s window while the phone takes the first 10 s. With a median of 1 s this affects only a small share of clips, but the count was not printed.

**Licence:** CC BY-NC-SA 4.0 (non-commercial, share-alike). Fine for a university project; a model trained on it should not ship in a commercial app. This repo only downloads it and does not store the audio.

Data: CatMeows, Ludovico et al. 2020, Zenodo record 4008297. Check the licence on the record before redistributing; this repo only downloads it.
