# MyPet behaviour model: step-by-step spikes

Each step is one notebook that runs free on Google Colab (open it from GitHub in Colab, then Runtime > Run all).
Results are copied into `results/` and summarised here, so the team can check them and agree or disagree in Semester 1.

Rules these follow (Dr Yam, 18 Sep 2026; proposal report): machine learning, not generative AI; free; the clip never leaves the phone; likelihoods only, never a diagnosis.

| Step | Notebook | Status |
|---|---|---|
| 1 | `01_clap_catmeows_spike.ipynb`: CLAP zero-shot vs CLAP embeddings + logistic regression on CatMeows | Done 19 Nov 2026 |
| 2 | Run the planned on-device file (`Xenova/clap-htsat-unfused` ONNX) and check it gives the same embeddings as step 1 | Next |
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
- It is still weak. Isolation meows are recognised best; food and brushing get mixed up. Results on unseen cats are much lower than what you get if the same cat is in train and test, which is why we split by cat.
- The test split has only 4 cats, so the single-split numbers jump around. The 7-fold number is the one to quote.
- CatMeows clips are 1 to 4 s (median 1.8 s) and were repeat-padded to 10 s. The app plans 10 s recordings, so real clips may hold several meows. Worth testing once we record our own.

**Honest wording for the app and report:** show likelihoods with "not a diagnosis", and say the behaviour check is an early estimate. This matches Dr Yam's line that logging is the minimum and AI is the best case.

Data: CatMeows, Ludovico et al. 2020, Zenodo record 4008297. Check the licence on the record before redistributing; this repo only downloads it.
