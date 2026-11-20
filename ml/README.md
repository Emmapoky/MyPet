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
| 5 | `flutter/behaviour_bench/tool/build_test_library.py`: train the classifiers the phone uses (cats, dog energy, dog mood) with the exact phone pipeline, and pack the held-out clips | Done 19 Nov 2026 |
| 6 | `flutter/behaviour_bench` Test library screen: run every held-out clip on the iPhone, true label vs result, play, score | Done 19 Nov 2026 (iPhone) |
| 7 | `build_test_library.py --sound-evidence`: the report's own labels (Table 4.2) and the sound evidence that checks it is the right animal | Done 19 Nov 2026 (iPhone) |
| 8 | `build_online_test.py`: 144 clips recorded by ordinary people (Wikimedia Commons audio and video, ESC-50) | Done 19 Nov 2026 (iPhone) |
| 9 | `09_compare_free_models.ipynb`: is another free audio model better than CLAP? (AST, YAMNet, PANNs) | Done 19 Nov 2026 |
| 10 | ML Lab "Try a clip": record near a pet or pick a video on the phone | Done 19 Nov 2026 (iPhone) |
| 11 | `build_photo_check.py`, `check_short_clips.py`: the picture half of the clip check, and 5 s vs 10 s clips | Done 19 Nov 2026 (Mac); picture on the iPhone not yet run |
| 12 | `12_how_many_clips.ipynb`: learning curves, how many labelled clips the check needs, and whether more animals or more clips help | Done |
| 13 | `build_video_library.py`: real Commons videos of dogs and cats in the Test library, checked by picture and sound | Done 19 Nov 2026 (iPhone) |
| later | Android timing on a borrowed phone; YAMNet only if needed | Later |

## For Li Shen: how to retrain and test

The **MyPet ML Lab** (`flutter/behaviour_bench`) is the team's test app. It is not part of the MyPet app. It runs exactly what the app runs, on the phone, and scores it. On a Mac with Flutter, Xcode and Python 3:

```sh
cd ml/flutter/behaviour_bench
./tool/fetch_model.sh                                   # CLAP audio model, 34.3 MB (not in git)
python3 -m venv .venv
.venv/bin/pip install numpy scipy scikit-learn onnxruntime torch transformers av datasets pillow torchvision

.venv/bin/python tool/build_test_library.py --sound-evidence   # step 7: trains the classifiers, packs held-out clips
.venv/bin/python tool/build_online_test.py                     # step 8: adds 144 online clips
.venv/bin/python tool/build_photo_check.py                     # step 11: picture model, gate, combine weight
.venv/bin/python tool/check_short_clips.py                     # step 11b: 5 s vs 10 s clips
.venv/bin/python tool/build_video_library.py                   # step 13: videos (picture + sound) in the Test library

flutter pub get
flutter run -d <iphone-id> --profile                           # ML Lab home: Test library, Try a clip, Timing
flutter run -d <iphone-id> --profile --dart-define=AUTORUN_LIBRARY=true   # runs the whole library, prints LIBRARY_JSON
```

- **Retrain with new data:** add a loader next to `load_cats()` / `load_dogs()` in `tool/build_test_library.py`, keep test animals out of training (split by animal, not by clip), and rerun the commands above. Scores go to `ml/results/`.
- **Try another audio model:** `09_compare_free_models.ipynb` in Colab uses the same splits and the same classifier, so only the model changes.
- **Ship to the app:** `app/tool/get_behaviour_model.sh` copies `classifiers.json`, `sound_evidence.json` and `photo_classifiers.json` from `assets/test_library/` and downloads the models.
- **Check the phone matches Python:** the Test library prints `max_gap_vs_python`; it should be 0.0.

Downloads are cached in `tool/.cache/`. Clips and classifier files are not in git (dataset licences).

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

## Steps 5 and 6 result (test library on the iPhone, 19 Nov 2026)

`tool/build_test_library.py` trained the three classifiers the app will use, with the exact phone pipeline (first 10 s, `reference/` features, quantized ONNX), on training animals only. It then packed 294 held-out clips: 94 meows from 4 cats it never saw, and 200 barks from the dogs in EmotionalCanines' test set. The **Test library** screen in `flutter/behaviour_bench` runs them all on the phone, shows each result next to the true label, plays the clip, and scores the set.

| Classifier | Held-out clips | Right | Macro F1 |
|---|---|---|---|
| Cat situation (food / brushed / alone) | 94 (4 cats) | 34 (36%) | 0.35 |
| Dog energy (calm / medium / excited) | 200 | 100 (50%) | 0.50 |
| Dog mood (negative / neutral / positive) | 200 | 89 (45%) | 0.42 |

On the iPhone: median 112 ms per clip, fully offline, and the largest gap between the phone's likelihoods and Python's was 0.0. The phone gives exactly the training script's answers.

**What this means**

- This is a demo set, not the headline number. The cat test holds only 4 cats, so it lands below step 1's 7-fold 0.49. Quote 0.49 for cats. In this split the cat model mostly misses "waiting for food" (2 of 14 right).
- Dogs match step 4 (0.50 energy, 0.42 mood). Negative barks are still the weak spot: 14 of 66 were called negative, and most of the rest were called positive. The app must not sound sure about mood.
- Dataset clips are 1 to 4 s. Next, check a few of our own 10 s recordings of real pets.

Full numbers and confusion matrices: `results/05_test_library.json`.

Data: CatMeows, Ludovico et al. 2020, Zenodo record 4008297. Check the licence on the record before redistributing; this repo only downloads it.

## Step 7 result (the report's own labels, 19 Nov 2026)

Same held-out clips as step 5, now with the labels in report Table 4.2, plus CLAP zero-shot "sound evidence" that checks the sound came from the chosen animal.

| Classifier | Held-out clips | Macro F1 | Chance |
|---|---|---|---|
| Cat: likely hungry / reacting to handling / stressed in a strange place | 94 (4 cats) | 0.38 | 0.33 |
| Dog: likely happy or playful / calm / sad or uneasy / upset | 200 | 0.36 | 0.25 |
| Dog energy | 200 | 0.50 | 0.33 |
| Dog mood | 200 | 0.42 | 0.33 |

The iPhone gives exactly Python's answers (largest gap 0.0), about 110 to 130 ms per clip. Full numbers: `results/07_report_labels.json`.

## Step 8 result (clips recorded by ordinary people, 19 Nov 2026)

144 clips nobody in the datasets recorded: 64 from Wikimedia Commons (including 9 videos, only the sound used) and 80 from ESC-50.

- **Cat or dog, from the sound alone:** 136 of 144 right. Across all 438 clips in the Test library on the iPhone: 395 right (90%).
- **Type of sound (Commons):** 48 of 64. Purrs 15/15, barks 17/18, growls 4/6, meows 10/18 (5 heard as dog howls), hisses 1/4 (3 heard as dog growls), whimpers 0/2.
- **Feeling:** the dog classifier says "upset" for most ordinary barks (13 of 18 Commons, 33 of 40 ESC-50). Barks recorded at home are not like the dataset's barks, so the feeling must stay "likely", with "Not sure" below 50%.

Full numbers: `results/08_online_clips.json`.

## Step 9 result (is another free model better? 19 Nov 2026)

Same data, same splits, same classifier. Only the model that turns sound into numbers changes. Macro F1, higher is better:

| Model | Cat | Dog energy | Dog mood | Dog 4 report labels |
|---|---|---|---|---|
| **CLAP htsat-unfused (current)** | 0.53 | 0.54 | 0.48 | 0.38 |
| CLAP larger_clap_general | 0.53 | 0.55 | 0.45 | 0.39 |
| AST (AudioSet) | 0.52 | 0.49 | 0.49 | **0.43** |
| YAMNet | 0.42 | 0.49 | 0.46 | 0.38 |
| PANNs CNN14 | **0.54** | 0.49 | 0.41 | 0.36 |

**Decision: keep CLAP.** No free model wins across the board. AST is 0.04 better on the four dog labels but worse on energy, about 2.5 times bigger, and has no tested phone version. YAMNet, the report's fallback, is clearly worse on cats. The weak spot is the data (few animals, lab recordings), not the model. Full numbers: `results/09_free_models.json`.

## Step 11b result (5 s clips vs 10 s, 19 Nov 2026)

The app records one clip of 5 to 10 s. On the 46 test clips longer than 5 s (mostly Commons recordings), keeping only the first 5 s gave: cat or dog right 40 vs 42 (10 s), sound type right 29 vs 30 of 41, same feeling on 35 of 46. **5 s works but 10 s is a little better**, so the app records up to 10 s and lets the user stop from 5 s. Most dataset clips are under 2 s (median 1.8 s) and are repeat-padded already. Full numbers: `results/11_short_clips.json`.

## Step 11 result (the picture half of the clip, 19 Nov 2026)

The app records one clip. The sound and the picture are checked separately, then combined (Erwyna, 19 Nov). The report had kept picture analysis as a later extension because a video's background adds noise (Dr Yam, 18 Sep), so this needs to go on the list for Dr Yam.

Picture model: CLIP ViT-B/32 image encoder (free, MIT licence, quantized ONNX, 85 MB on the phone). Three frames from the clip, averaged.

| Check | Test | Result |
|---|---|---|
| Is a dog in view? | CIFAR-10 test, 1,000 dog photos | 886 right (89%) |
| Is a cat in view? | CIFAR-10 test, 1,000 cat photos | 717 right (72%) |
| Is it neither? | CIFAR-10 test, 8,000 other photos | 7,693 right (96%) |
| Is a dog in view? | Dog Emotion v2 test, 800 dog photos | 790 said dog |
| Dog feeling from a photo (4 report labels) | Dog Emotion v2 test, 739 photos (61 near copies of training photos removed) | macro F1 0.83 |

**How to read this**

- The cat result is low partly because CIFAR-10 photos are 32 by 32 pixels. Real phone frames are much sharper. It should be rechecked on our own videos.
- The dog feeling from a photo looks far stronger than from sound (0.83 against 0.36). Be careful with this. The photos are posed internet pictures, labelled by the person who uploaded them (method not stated), with licence creativeml-openrail-m. Phone frames of a moving dog will be harder. Treat 0.83 as an upper bound, not a promise.
- Most misses are calm versus sad or uneasy (32 calm dogs called sad or uneasy, and 24 the other way). 19 of 199 upset dogs were called happy.
- **Combining:** no dataset labels the same pet's picture and sound together, so the weights cannot be fitted on paired clips. They come from each side's held-out score: sound weight = 0.36 / (0.36 + 0.83) = 0.3, picture 0.7. For cats, no cat expression photo set with a clear licence could be downloaded, so the picture only checks a cat is in view and the feeling comes from the sound.
- The ML Lab's **Try a clip** now checks the picture too when you pick a video.

Full numbers: `results/11_photo_check.json`. Data: CIFAR-10 (Krizhevsky 2009); Dog Emotion Dataset v2 (huggingface.co/datasets/Dewa/Dog_Emotion_Dataset_v2).

## Step 13 result (real videos in the Test library, 19 Nov 2026)

80 videos from Wikimedia Commons (40 dogs, 40 cats, free licences, source link on each), checked the way the app checks a clip: the loudest 10 s of the soundtrack through CLAP, three frames through the CLIP image model. 46 more were skipped (27 had no soundtrack, 15 would not decode, 3 downloads were cut short, 1 frame error). The Test library on the iPhone now holds 518 clips (235 MB).

| What | Right |
|---|---|
| Cat or dog from the **picture** | 54 of 80 (dogs 23 of 40, cats 31 of 40) |
| Cat or dog from the **sound** | 47 of 80 (dogs 21 of 40, cats 26 of 40) |
| Both agree and are right | 35 of 80 |
| At least one is right | 66 of 80 |

**How to read this**

- Real videos are much harder than the datasets. Many Commons videos are about something else (people talking, music, other animals, a pet far from the camera), so the picture often says "other" (23 of 80) and the sound often says speech or quiet.
- The picture and the sound fail on different videos, so using both helps: at least one is right on 66 of 80 (83%), against 54 (68%) for the picture alone.
- For these videos the feeling has no true label, so it is not scored. 22 of 40 dog videos came out "upset", the same lean seen in step 8, so the app must keep saying "likely" and show the other possibilities.
- The phone's answers match Python's on the counts. The largest difference in a likelihood is 0.115, up from 0.0 for sound only. It comes from the picture gate, which multiplies small differences in the image numbers by about 100, and it did not change any of the counts.

Full numbers: `results/13_video_clips.json`.

### Step 12: how many clips does the check need?

Erwyna asked whether training on 2,000 to 3,000 clips would make the check more accurate. Instead of guessing, `12_how_many_clips.ipynb` (Colab, free GPU) trains the app's classifier on 10% to 100% of the clips (5 seeds each) and scores it on animals it has not heard. Numbers are macro F1; results in `results/12_how_many_clips.json`.

| Task | Clips now | F1 now | F1 at 2x | F1 at 3,000 | Reading |
|---|---|---|---|---|---|
| Cat (3 reasons) | 377 | 0.51 | 0.52 | 0.52 | Flat after about 190 clips. More clips from the same cats do not help. |
| Dog energy | 1,200 | 0.52 | 0.53 | 0.54 | Flat. |
| Dog mood | 1,200 | 0.48 | 0.49 | 0.50 | Slow climb. Curve fit is unreliable here. |
| Dog 4 feelings | 1,200 | 0.38 | 0.42 | 0.42 | Still climbing: about +0.04 at 3,000 clips. |

Cats by number of different cats (same total clips per cat): 2 cats 0.31, 4 cats 0.43, 8 cats 0.44, 12 cats 0.51, 16 cats 0.49. The spread between draws is 0.1 to 0.15, so this is a trend, not a measurement.

What this means:
- 2,000 to 3,000 more clips of the same kind would add about 0.01 for cats and about 0.04 for the dog 4-feeling check at best. That is not worth chasing.
- What helps is more different animals, not more clips from the same ones, and only clips where someone knows how the animal felt. Unlabelled clips (for example from video sites) can improve the sound type (bark, purr) but not the feeling.
- The bigger gain is already in the picture: for dogs the photo model is much stronger than sound (step 11), and the app combines both.
- Limits: the curves come from the small labelled sets we have (CatMeows, 21 cats; EmotionalCanines); the extrapolation is a power-law fit and an estimate, not a promise.
