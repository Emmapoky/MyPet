"""MyPet ML step 5: train the cat and dog classifiers the phone will use, and build the
test library of held-out clips for the app's Test library screen.

Everything runs exactly like the phone does it:
  48 kHz mono clip -> ml/reference NumPy features (first 10 s, repeat-pad)
  -> quantized CLAP ONNX (the same file the app ships) -> 512 numbers, scaled to length 1
  -> logistic regression -> likelihood for each label.

Classifiers (trained only on training animals; the test library holds other animals):
  cat_context   CatMeows (Ludovico et al. 2020, Zenodo 4008297): waiting for food / being brushed /
                alone in a strange place. Same 4 test cats as step 1; trained on the other 17.
  dog_arousal   EmotionalCanines (Dang et al. 2025, CC BY-NC-SA 4.0): calm / medium / excited.
  dog_valence   EmotionalCanines: negative / neutral / positive. Both use the dataset's own
                train/test split, Husky and Shiba Inu together (step 4 showed one model is fine).

Writes (all gitignored except the results file):
  assets/test_library/classifiers.json   weights for the phone (scaler folded into the weights)
  assets/test_library/manifest.json      one entry per test clip: true labels + Python's likelihoods
  assets/test_library/*.wav              the test clips, 48 kHz mono 16-bit, at most 10 s
  assets/test_library/sound_evidence.json  CLAP text embeddings for the sound-evidence labels (--sound-evidence)
  ../../results/07_report_labels.json    scores on the held-out clips

Run from ml/flutter/behaviour_bench after tool/fetch_model.sh:
  .venv/bin/pip install numpy scipy scikit-learn onnxruntime
  .venv/bin/python tool/build_test_library.py
Downloads (about 60 MB) are cached in tool/.cache/.
"""
import argparse, glob, io, json, os, sys, time, urllib.request, zipfile
from concurrent.futures import ThreadPoolExecutor
from fractions import Fraction

import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, confusion_matrix, f1_score
from sklearn.model_selection import GridSearchCV, GroupKFold, GroupShuffleSplit, StratifiedKFold
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(APP, "..", "..", "reference"))
from clap_features import SR, N_SAMPLES, clap_input_features  # noqa: E402

CACHE = os.path.join(HERE, ".cache")
OUT = os.path.join(APP, "assets", "test_library")
RESULTS = os.path.join(APP, "..", "..", "results", "07_report_labels.json")
MODEL = os.path.join(APP, "assets", "models", "clap_audio_quantized.onnx")
SEED = 42

CAT_CLASSES = ["F", "B", "I"]
# What the app says (report Table 4.2)
CAT_NAMES = {"F": "Likely hungry", "B": "Likely reacting to handling", "I": "Likely stressed in a strange place"}
# Dog labels from report Table 4.2: positive -> happy or playful; neutral -> calm;
# negative with high arousal -> upset; negative with low or medium arousal -> sad or uneasy.
DOG_REPORT = ["happy", "calm", "sad_uneasy", "upset"]
DOG_REPORT_NAMES = {"happy": "Likely happy or playful", "calm": "Likely calm",
                    "sad_uneasy": "Likely sad or uneasy", "upset": "Likely upset"}


def dog_report_label(arousal, valence):
    if valence == "Positive":
        return "happy"
    if valence == "Neutral":
        return "calm"
    return "upset" if arousal == "High" else "sad_uneasy"


# CLAP zero-shot sound evidence (report 4.2: "its sound labels, such as whimpering, will be shown as evidence")
SOUNDS = [("dog_bark", "dog", "Barking", "the sound of a dog barking"),
          ("dog_whimper", "dog", "Whimpering", "the sound of a dog whimpering"),
          ("dog_growl", "dog", "Growling", "the sound of a dog growling"),
          ("dog_howl", "dog", "Howling", "the sound of a dog howling"),
          ("cat_meow", "cat", "Meowing", "the sound of a cat meowing"),
          ("cat_purr", "cat", "Purring", "the sound of a cat purring"),
          ("cat_hiss", "cat", "Hissing", "the sound of a cat hissing"),
          ("cat_yowl", "cat", "Yowling", "the sound of a cat yowling"),
          ("speech", "other", "People talking", "the sound of people talking"),
          ("quiet", "other", "Background noise", "quiet background noise in a room")]
DOG_TASKS = {"arousal": ["Low", "Medium", "High"], "valence": ["Negative", "Neutral", "Positive"]}
DOG_NAMES = {"Low": "Calm", "Medium": "Medium", "High": "Excited",
             "Negative": "Negative", "Neutral": "Neutral", "Positive": "Positive"}
DOG_REPO = "https://raw.githubusercontent.com/tmdang1101/EmotionalCanines/main/"
DOG_MEDIA = "https://media.githubusercontent.com/media/tmdang1101/EmotionalCanines/main/"


# ---------- audio ----------
def read_wav_48k(data: bytes) -> np.ndarray:
    sr, x = wavfile.read(io.BytesIO(data))
    if x.dtype.kind == "i":
        x = x.astype(np.float64) / float(np.iinfo(x.dtype).max + 1)
    elif x.dtype.kind == "u":
        x = (x.astype(np.float64) - 128.0) / 128.0
    else:
        x = x.astype(np.float64)
    if x.ndim == 2:
        x = x.mean(axis=1)
    if sr != SR:
        f = Fraction(SR, sr).limit_denominator(1000)
        x = resample_poly(x, f.numerator, f.denominator)
    return x[:N_SAMPLES]  # the phone only ever looks at the first 10 s


def to_pcm16(x: np.ndarray) -> np.ndarray:
    return np.clip(np.round(x * 32768.0), -32768, 32767).astype(np.int16)


def from_pcm16(x: np.ndarray) -> np.ndarray:
    return x.astype(np.float64) / 32768.0  # what the app's WAV reader does


# ---------- data ----------
def fetch(url: str, path: str) -> str:
    if not (os.path.exists(path) and os.path.getsize(path) > 1000):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        urllib.request.urlretrieve(url, path + ".part")
        os.replace(path + ".part", path)
    return path


def load_cats():
    """Returns list of dicts with the clip (as 16-bit PCM), cat id and label. Same order as step 1."""
    root = os.path.join(CACHE, "catmeows")
    if not glob.glob(os.path.join(root, "**", "*.wav"), recursive=True):
        rec = json.load(urllib.request.urlopen("https://zenodo.org/api/records/4008297"))
        zf = [f for f in rec["files"] if f["key"].endswith(".zip")][0]
        z = fetch(zf["links"]["self"], os.path.join(CACHE, "catmeows.zip"))
        zipfile.ZipFile(z).extractall(root)
    # step 1 sorted paths that all began with "catmeows/"; sorting the part below root matches it
    files = sorted(glob.glob(os.path.join(root, "**", "*.wav"), recursive=True),
                   key=lambda p: os.path.relpath(p, root))
    clips = []
    for p in files:
        b = os.path.basename(p)
        clips.append({"name": b[:-4], "species": "cat", "cat": b.split("_")[1],
                      "label": b.split("_")[0], "pcm": to_pcm16(read_wav_48k(open(p, "rb").read())),
                      "source": "CatMeows (Ludovico et al. 2020), zenodo.org/records/4008297"})
    return clips


def load_dogs():
    import csv
    clips = []
    jobs = []
    for breed in ["husky", "shiba"]:
        for split in ["train", "test"]:
            csvp = fetch(DOG_REPO + f"{breed}_{split}_labels.csv", os.path.join(CACHE, "dogs", f"{breed}_{split}_labels.csv"))
            for row in csv.DictReader(open(csvp)):
                rel = f"{breed}/{split}/{row['audio_id']}.wav"
                jobs.append((rel, breed, split, row))
    with ThreadPoolExecutor(8) as ex:
        list(ex.map(lambda j: fetch(DOG_MEDIA + j[0], os.path.join(CACHE, "dogs", j[0])), jobs))
    for rel, breed, split, row in jobs:
        data = open(os.path.join(CACHE, "dogs", rel), "rb").read()
        if data[:4] != b"RIFF":
            raise SystemExit(f"{rel} is not a WAV file (Git LFS pointer?)")
        clips.append({"name": row["audio_id"], "species": "dog", "breed": breed, "split": split,
                      "arousal": row["arousal"], "valence": row["valence"],
                      "pcm": to_pcm16(read_wav_48k(data)),
                      "source": "EmotionalCanines (Dang et al. 2025), github.com/tmdang1101/EmotionalCanines, CC BY-NC-SA 4.0"})
    return clips


# ---------- model ----------
class Embedder:
    def __init__(self, fake=False):
        self.fake = fake
        if fake:  # plumbing test only: a fixed random projection instead of CLAP
            self.P = np.random.default_rng(0).standard_normal((1001 * 64, 512)).astype(np.float32) / 250
        else:
            import onnxruntime as ort
            self.s = ort.InferenceSession(MODEL, providers=["CPUExecutionProvider"])

    def __call__(self, x):
        f = clap_input_features(x)
        e = (f.reshape(-1) @ self.P) if self.fake else self.s.run(["audio_embeds"], {"input_features": f})[0][0]
        e = e.astype(np.float64)
        return e / np.linalg.norm(e)


def cached_embeddings(name, clips, emb):
    """Embeddings are slow on a laptop CPU; cache them next to the downloads."""
    path = os.path.join(CACHE, f"emb_{name}{'_fake' if emb.fake else ''}.npz")
    names = np.array([c["name"] for c in clips])
    if os.path.exists(path):
        z = np.load(path)
        if len(z["names"]) == len(names) and (z["names"] == names).all():
            return z["X"]
    X = np.stack([emb(from_pcm16(c["pcm"])) for c in clips])
    np.savez(path, X=X, names=names)
    return X


def sound_text_embeddings():
    """Text side of CLAP for the sound-evidence prompts (PyTorch; needs torch + transformers)."""
    import torch
    from transformers import ClapModel, ClapProcessor
    model = ClapModel.from_pretrained("laion/clap-htsat-unfused").eval()
    proc = ClapProcessor.from_pretrained("laion/clap-htsat-unfused")
    tok = proc.tokenizer([s[3] for s in SOUNDS], padding=True, return_tensors="pt")
    with torch.no_grad():
        t = model.text_projection(model.text_model(input_ids=tok["input_ids"],
                                                   attention_mask=tok["attention_mask"]).pooler_output)
        t = torch.nn.functional.normalize(t, dim=-1).numpy().astype(np.float64)
        scale = float(model.logit_scale_a.exp())
    return t, scale


def sound_probs(T, scale, x):
    z = scale * (T @ x)
    z = np.exp(z - z.max())
    return z / z.sum()


def export(pipe, classes, names):
    """Fold StandardScaler into the logistic regression: logits = W x + b."""
    sc, lr = pipe.named_steps["standardscaler"], pipe.named_steps["logisticregression"]
    W = lr.coef_ / sc.scale_
    b = lr.intercept_ - (lr.coef_ * (sc.mean_ / sc.scale_)).sum(axis=1)
    return {"classes": classes, "names": [names[c] for c in classes],
            "W": [[round(float(v), 7) for v in row] for row in W], "b": [round(float(v), 7) for v in b]}


def probs(clf, x):
    z = np.array(clf["W"]) @ x + np.array(clf["b"])
    z = np.exp(z - z.max())
    return z / z.sum()


def score(name, yt, yp, classes):
    r = {"clips": int(len(yt)), "accuracy": round(accuracy_score(yt, yp), 3),
         "macro_f1": round(f1_score(yt, yp, average="macro"), 3),
         "confusion_rows_true_cols_pred": confusion_matrix(yt, yp, labels=list(range(len(classes)))).tolist(),
         "class_order": classes}
    print(f"{name:12s} {r['clips']:4d} test clips  acc {r['accuracy']:.3f}  macro F1 {r['macro_f1']:.3f}")
    return r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fake-model", action="store_true", help="plumbing test without the ONNX file")
    ap.add_argument("--skip-cats", action="store_true", help="plumbing test where zenodo is unreachable")
    ap.add_argument("--sound-evidence", action="store_true",
                    help="also export CLAP zero-shot sound labels (needs torch + transformers)")
    a = ap.parse_args()
    t0 = time.time()
    emb = Embedder(a.fake_model)
    os.makedirs(OUT, exist_ok=True)
    for old in glob.glob(os.path.join(OUT, "*.wav")):
        os.remove(old)
    classifiers, manifest, results = {}, [], {}

    if not a.skip_cats:
        cats = load_cats()
        X = cached_embeddings("cats", cats, emb)
        y = np.array([CAT_CLASSES.index(c["label"]) for c in cats])
        g = np.array([c["cat"] for c in cats])
        # the exact step 1 split: 70/15/15 by cat with seed 42; the test cats stay out of training
        tr, rest = next(GroupShuffleSplit(1, test_size=0.30, random_state=SEED).split(X, y, g))
        va_i, te_i = next(GroupShuffleSplit(1, test_size=0.50, random_state=SEED).split(X[rest], y[rest], g[rest]))
        te = rest[te_i]
        trn = np.setdiff1d(np.arange(len(y)), te)
        grid = GridSearchCV(make_pipeline(StandardScaler(), LogisticRegression(max_iter=5000)),
                            {"logisticregression__C": [0.01, 0.1, 1, 10],
                             "logisticregression__class_weight": [None, "balanced"]}, scoring="f1_macro",
                            cv=GroupKFold(5)).fit(X[trn], y[trn], groups=g[trn])
        clf = export(grid.best_estimator_, CAT_CLASSES, CAT_NAMES)
        classifiers["cat_context"] = clf
        P = np.stack([probs(clf, X[i]) for i in te])
        results["cat_context"] = score("cat_context", y[te], P.argmax(1), CAT_CLASSES)
        results["cat_context"].update(C=grid.best_params_["logisticregression__C"],
                                      class_weight=grid.best_params_["logisticregression__class_weight"],
                                      train_cats=len(set(g[trn])), test_cats=sorted(set(g[te])))
        for i, p in zip(te, P):
            c = cats[i]
            wavfile.write(os.path.join(OUT, c["name"] + ".wav"), SR, c["pcm"])
            manifest.append({"file": c["name"] + ".wav", "species": "cat", "animal": "cat " + c["cat"],
                             "truth": {"cat_context": c["label"]},
                             "python": {"cat_context": [round(float(v), 5) for v in p]},
                             "_x": X[i],
                             "seconds": round(len(c["pcm"]) / SR, 2), "source": c["source"]})

    dogs = load_dogs()
    X = cached_embeddings("dogs", dogs, emb)
    tr = np.array([d["split"] == "train" for d in dogs])
    te = ~tr
    dogP = {}
    for task, classes in DOG_TASKS.items():
        y = np.array([classes.index(d[task]) for d in dogs])
        grid = GridSearchCV(make_pipeline(StandardScaler(), LogisticRegression(max_iter=5000)),
                            {"logisticregression__C": [0.001, 0.01, 0.1, 1]}, scoring="f1_macro",
                            cv=StratifiedKFold(5, shuffle=True, random_state=SEED)).fit(X[tr], y[tr])
        clf = export(grid.best_estimator_, classes, DOG_NAMES)
        classifiers["dog_" + task] = clf
        dogP[task] = np.stack([probs(clf, x) for x in X[te]])
        results["dog_" + task] = score("dog_" + task, y[te], dogP[task].argmax(1), classes)
        results["dog_" + task]["C"] = grid.best_params_["logisticregression__C"]
    # the report's four dog labels, one classifier trained directly on them
    y = np.array([DOG_REPORT.index(dog_report_label(d["arousal"], d["valence"])) for d in dogs])
    grid = GridSearchCV(make_pipeline(StandardScaler(), LogisticRegression(max_iter=5000)),
                        {"logisticregression__C": [0.001, 0.01, 0.1, 1],
                         "logisticregression__class_weight": [None, "balanced"]}, scoring="f1_macro",
                        cv=StratifiedKFold(5, shuffle=True, random_state=SEED)).fit(X[tr], y[tr])
    clf = export(grid.best_estimator_, DOG_REPORT, DOG_REPORT_NAMES)
    classifiers["dog_report"] = clf
    dogP["report"] = np.stack([probs(clf, x) for x in X[te]])
    results["dog_report"] = score("dog_report", y[te], dogP["report"].argmax(1), DOG_REPORT)
    results["dog_report"].update(C=grid.best_params_["logisticregression__C"],
                                 class_weight=grid.best_params_["logisticregression__class_weight"],
                                 train_counts=np.bincount(y[tr], minlength=4).tolist(),
                                 test_counts=np.bincount(y[te], minlength=4).tolist())
    # comparison only: the same four labels built from the separate energy and mood classifiers
    pa, pv = dogP["arousal"], dogP["valence"]  # [Low, Medium, High], [Negative, Neutral, Positive]
    derived = np.stack([pv[:, 2], pv[:, 1], pv[:, 0] * (pa[:, 0] + pa[:, 1]), pv[:, 0] * pa[:, 2]], 1)
    results["dog_report_from_energy_and_mood"] = score("  (derived)", y[te], derived.argmax(1), DOG_REPORT)
    for k, i in enumerate(np.where(te)[0]):
        d = dogs[i]
        wavfile.write(os.path.join(OUT, d["name"] + ".wav"), SR, d["pcm"])
        manifest.append({"file": d["name"] + ".wav", "species": "dog", "animal": d["breed"].capitalize(),
                         "truth": {"dog_report": dog_report_label(d["arousal"], d["valence"]),
                                   "dog_arousal": d["arousal"], "dog_valence": d["valence"]},
                         "python": {f"dog_{t}": [round(float(v), 5) for v in dogP[t][k]]
                                    for t in ["report", *DOG_TASKS]},
                         "_x": X[i],
                         "seconds": round(len(d["pcm"]) / SR, 2), "source": d["source"]})

    if a.sound_evidence:
        T, scale = sound_text_embeddings()
        json.dump({"keys": [s[0] for s in SOUNDS], "species": [s[1] for s in SOUNDS],
                   "names": [s[2] for s in SOUNDS], "prompts": [s[3] for s in SOUNDS], "scale": scale,
                   "T": [[round(float(v), 7) for v in row] for row in T]},
                  open(os.path.join(OUT, "sound_evidence.json"), "w"))
        species_right, top_counts = 0, {}
        for m in manifest:
            p = sound_probs(T, scale, m["_x"])
            m["python"]["sound"] = [round(float(v), 5) for v in p]
            by = {sp: sum(p[j] for j, s_ in enumerate(SOUNDS) if s_[1] == sp) for sp in ["dog", "cat", "other"]}
            species_right += max(by, key=by.get) == m["species"]
            key = f"{m['species']}->{SOUNDS[int(p.argmax())][0]}"
            top_counts[key] = top_counts.get(key, 0) + 1
        results["sound_evidence"] = {"clips": len(manifest),
                                     "species_from_sound_right": species_right,
                                     "top_sound_counts": dict(sorted(top_counts.items()))}
        print(f"sound evidence: species right from sound alone on {species_right}/{len(manifest)} clips; "
              f"top sounds {results['sound_evidence']['top_sound_counts']}")
    for m in manifest:
        m.pop("_x", None)
    json.dump(classifiers, open(os.path.join(OUT, "classifiers.json"), "w"))
    json.dump(manifest, open(os.path.join(OUT, "manifest.json"), "w"))
    results["note"] = ("Held-out clips only (other cats, other dogs). Phone pipeline: first 10 s, ml/reference "
                       "features, quantized CLAP ONNX, L2-normalised, logistic regression.")
    results["fake_model"] = a.fake_model
    if not a.fake_model:
        json.dump(results, open(RESULTS, "w"), indent=1)
    mb = sum(os.path.getsize(p) for p in glob.glob(os.path.join(OUT, "*"))) / 1e6
    print(f"test library: {len(manifest)} clips, {mb:.1f} MB in assets/test_library/ ({time.time()-t0:.0f} s)")
    print("STEP7_JSON", json.dumps({k: {kk: vv for kk, vv in v.items() if kk != "confusion_rows_true_cols_pred"}
                                    for k, v in results.items() if isinstance(v, dict)}))


if __name__ == "__main__":
    main()
