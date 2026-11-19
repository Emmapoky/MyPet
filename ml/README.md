# MyPet behaviour model: step-by-step spikes

Each step is one notebook that runs free on Google Colab (open it from GitHub in Colab, then Runtime > Run all).
Results are copied into `results/` and summarised here, so the team can check them and agree or disagree in Semester 1.

Rules these follow (Dr Yam, 18 Sep 2026; proposal report): machine learning, not generative AI; free; the clip never leaves the phone; likelihoods only, never a diagnosis.

| Step | Notebook | Status |
|---|---|---|
| 1 | `01_clap_catmeows_spike.ipynb`: CLAP zero-shot vs CLAP embeddings + logistic regression on CatMeows | Done 19 Nov 2026 |
| 2 | `02_onnx_matches_pytorch.ipynb`: the planned on-device ONNX files give the same embeddings and the same result as step 1 | Done 19 Nov 2026 |
| 2b | Compute the same log-mel `input_features` in the app (Swift in this repo now; Dart if the team moves to Flutter as the report plans) and check them against Python on a few clips | Next |
| 3 | Dogs: same test on EmotionalCanines | Later |
| 4 | YAMNet embeddings on the same splits (the fallback) | Later |

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

**Honest wording for the app and report:** show likelihoods with "not a diagnosis", and say the behaviour check is an early estimate. This matches Dr Yam's line that logging is the minimum and AI is the best case.

Data: CatMeows, Ludovico et al. 2020, Zenodo record 4008297. Check the licence on the record before redistributing; this repo only downloads it.
