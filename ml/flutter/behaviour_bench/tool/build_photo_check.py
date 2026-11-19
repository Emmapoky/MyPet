"""MyPet ML step 11: the picture half of the clip check.

The app records one clip (5 to 10 s). The sound goes through CLAP as before. A few frames from the
picture go through a free image model, and the two answers are combined into one result.

Picture pipeline (the phone does exactly this for each frame):
  frame -> shortest side resized to 224 (bicubic) -> centre crop 224x224 -> RGB / 255
  -> (x - mean) / std, channels first [1, 3, 224, 224]
  -> quantized CLIP ViT-B/32 image encoder (Xenova/clip-vit-base-patch32, MIT, ONNX) -> 512 numbers
  -> scaled to length 1 -> (a) the gate, (b) the dog feeling classifier.

  Gate     CLIP zero-shot (no training): "a photo of a dog" / "a photo of a cat" / other scenes.
           Tested on the CIFAR-10 test set (Krizhevsky 2009): 1000 cats, 1000 dogs, 8000 other.
  Dog      Logistic regression on Dog Emotion Dataset v2 (huggingface.co/datasets/Dewa/Dog_Emotion_Dataset_v2,
           licence on the page: creativeml-openrail-m; labels happy / relaxed / sad / angry, set by the
           uploader, method not stated). Mapped to the report's Table 4.2 names:
           happy -> "Likely happy or playful", relaxed -> "Likely calm", sad -> "Likely sad or uneasy",
           angry -> "Likely upset". Trained on its train split, scored on its test split. Test photos that
           are near copies of a training photo (cosine > 0.95) are counted and also left out in a second score.
  Cat      No downloadable cat expression set with a stated licence was found (Roboflow sets need an account),
           so the picture only confirms a cat is in view. The cat feeling comes from the sound.
  Combine  No dataset has the same pet's picture and sound labelled together, so the weights cannot be fitted
           on paired clips. They are set from each side's held-out macro F1 on the shared four dog labels:
           sound_weight = F1_sound / (F1_sound + F1_picture). Stated as an assumption in the README.

Writes:
  assets/models/clip_vision_quantized.onnx      (downloaded, not in git)
  assets/test_library/photo_classifiers.json    (not in git, like classifiers.json)
  ../../results/11_photo_check.json

Run from ml/flutter/behaviour_bench after tool/build_test_library.py:
  .venv/bin/pip install numpy scikit-learn onnxruntime torch torchvision transformers datasets pillow
  .venv/bin/python tool/build_photo_check.py
"""
import json, os, sys, time, urllib.request

import numpy as np
from PIL import Image
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, confusion_matrix, f1_score
from sklearn.model_selection import GridSearchCV, StratifiedKFold
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_test_library as base  # noqa: E402

APP = base.APP
MODEL = os.path.join(APP, "assets", "models", "clip_vision_quantized.onnx")
MODEL_URL = "https://huggingface.co/Xenova/clip-vit-base-patch32/resolve/main/onnx/vision_model_quantized.onnx"
OUT = os.path.join(APP, "assets", "test_library", "photo_classifiers.json")
RESULTS = os.path.join(APP, "..", "..", "results", "11_photo_check.json")
CACHE = os.path.join(HERE, ".cache")
MEAN = [0.48145466, 0.4578275, 0.40821073]
STD = [0.26862954, 0.26130258, 0.27577711]

DOG_MAP = {"happy": "happy", "relaxed": "calm", "sad": "sad_uneasy", "angry": "upset"}
GATE = [("dog", "dog", "a photo of a dog"), ("cat", "cat", "a photo of a cat"),
        ("person", "other", "a photo of a person"), ("room", "other", "a photo of an empty room"),
        ("animal", "other", "a photo of another animal"), ("object", "other", "a photo of an object"),
        ("outdoors", "other", "a photo of a street or a garden")]


def preprocess(img: Image.Image) -> np.ndarray:
    img = img.convert("RGB")
    w, h = img.size
    s = 224 / min(w, h)
    img = img.resize((max(224, round(w * s)), max(224, round(h * s))), Image.BICUBIC)
    w, h = img.size
    l, t = (w - 224) // 2, (h - 224) // 2
    x = np.asarray(img.crop((l, t, l + 224, t + 224)), dtype=np.float32) / 255.0
    x = (x - np.array(MEAN, np.float32)) / np.array(STD, np.float32)
    return x.transpose(2, 0, 1)[None]


class ImageEmbedder:
    def __init__(self):
        if not os.path.exists(MODEL):
            os.makedirs(os.path.dirname(MODEL), exist_ok=True)
            urllib.request.urlretrieve(MODEL_URL, MODEL + ".part")
            os.replace(MODEL + ".part", MODEL)
        import onnxruntime as ort
        self.s = ort.InferenceSession(MODEL, providers=["CPUExecutionProvider"])
        self.inp = self.s.get_inputs()[0].name
        names = [o.name for o in self.s.get_outputs()]
        self.out = "image_embeds" if "image_embeds" in names else names[0]

    def __call__(self, img):
        e = self.s.run([self.out], {self.inp: preprocess(img)})[0].reshape(-1).astype(np.float64)
        return e / np.linalg.norm(e)


def embed_all(name, images, emb):
    path = os.path.join(CACHE, f"img_{name}.npy")
    if os.path.exists(path):
        X = np.load(path)
        if len(X) == len(images):
            return X
    t = time.time()
    X = np.stack([emb(im) for im in images])
    np.save(path, X)
    print(f"  {name}: {len(X)} images embedded in {time.time() - t:.0f} s")
    return X


def gate_text():
    import torch
    from transformers import CLIPModel, CLIPTokenizer
    m = CLIPModel.from_pretrained("openai/clip-vit-base-patch32").eval()
    tok = CLIPTokenizer.from_pretrained("openai/clip-vit-base-patch32")
    with torch.no_grad():
        t = m.get_text_features(**tok([g[2] for g in GATE], padding=True, return_tensors="pt"))
        t = torch.nn.functional.normalize(t, dim=-1).numpy().astype(np.float64)
    return t, float(m.logit_scale.exp())


def gate_species(T, scale, x):
    p = base.sound_probs(T, scale, x)  # same softmax as the sound evidence
    by = {sp: sum(p[i] for i, g in enumerate(GATE) if g[1] == sp) for sp in ["dog", "cat", "other"]}
    return max(by, key=by.get)


def main():
    t0 = time.time()
    os.makedirs(CACHE, exist_ok=True)
    emb = ImageEmbedder()
    results = {}

    # ---- gate on CIFAR-10 test ----
    import torchvision
    cif = torchvision.datasets.CIFAR10(os.path.join(CACHE, "cifar10"), train=False, download=True)
    want = {3: "cat", 5: "dog"}
    imgs = [im for im, _ in cif]
    truth = [want.get(y, "other") for _, y in cif]
    X = embed_all("cifar10_test", imgs, emb)
    T, scale = gate_text()
    pred = [gate_species(T, scale, x) for x in X]
    by = {}
    for sp in ["dog", "cat", "other"]:
        idx = [i for i, t in enumerate(truth) if t == sp]
        by[sp] = {"images": len(idx), "right": sum(pred[i] == sp for i in idx)}
    results["gate_cifar10"] = by
    print("gate (CIFAR-10 test, 32x32 photos scaled up):", by)

    # ---- dog feelings ----
    from datasets import load_dataset
    ds = load_dataset("Dewa/Dog_Emotion_Dataset_v2")
    splits = list(ds.keys())
    tr_name = "train" if "train" in splits else splits[0]
    te_name = "test" if "test" in splits else splits[-1]
    feat = ds[tr_name].features
    img_col = [k for k, v in feat.items() if v.__class__.__name__ == "Image"][0]
    lab_col = [k for k, v in feat.items() if v.__class__.__name__ == "ClassLabel"][0]
    names = feat[lab_col].names
    print("dataset splits", {k: len(v) for k, v in ds.items()}, "labels", names)
    idx_map = [base.DOG_REPORT.index(DOG_MAP[n.lower()]) for n in names]
    Xtr = embed_all("dog_emotion_train", ds[tr_name][img_col], emb)
    Xte = embed_all("dog_emotion_test", ds[te_name][img_col], emb)
    ytr = np.array([idx_map[v] for v in ds[tr_name][lab_col]])
    yte = np.array([idx_map[v] for v in ds[te_name][lab_col]])
    near = (Xte @ Xtr.T).max(1) > 0.95
    grid = GridSearchCV(make_pipeline(StandardScaler(), LogisticRegression(max_iter=5000)),
                        {"logisticregression__C": [0.001, 0.01, 0.1, 1],
                         "logisticregression__class_weight": [None, "balanced"]}, scoring="f1_macro",
                        cv=StratifiedKFold(5, shuffle=True, random_state=base.SEED)).fit(Xtr, ytr)
    clf = base.export(grid.best_estimator_, base.DOG_REPORT, base.DOG_REPORT_NAMES)
    P = np.stack([base.probs(clf, x) for x in Xte])
    yp = P.argmax(1)

    def sc(m):
        return {"images": int(m.sum()), "accuracy": round(accuracy_score(yte[m], yp[m]), 3),
                "macro_f1": round(f1_score(yte[m], yp[m], average="macro"), 3)}
    allm = np.ones(len(yte), bool)
    results["dog_photo"] = {**sc(allm), "without_near_copies": sc(~near), "near_copies_in_test": int(near.sum()),
                            "confusion_rows_true_cols_pred": confusion_matrix(yte, yp, labels=range(4)).tolist(),
                            "class_order": base.DOG_REPORT, "train_images": int(len(ytr)),
                            "C": grid.best_params_["logisticregression__C"],
                            "class_weight": grid.best_params_["logisticregression__class_weight"]}
    print("dog_photo", {k: v for k, v in results["dog_photo"].items() if k != "confusion_rows_true_cols_pred"})
    # the gate on real dog photos too
    g = [gate_species(T, scale, x) for x in Xte]
    results["gate_dog_emotion_test"] = {"images": len(g), "said_dog": g.count("dog"), "said_cat": g.count("cat")}

    # ---- combine rule ----
    f1_sound = json.load(open(base.RESULTS))["dog_report"]["macro_f1"]
    f1_pic = results["dog_photo"]["without_near_copies"]["macro_f1"]
    w = round(f1_sound / (f1_sound + f1_pic), 2)
    results["combine"] = {"sound_weight": w, "f1_sound_held_out": f1_sound, "f1_picture_held_out": f1_pic,
                          "rule": "dogs: p = w * p_sound + (1 - w) * p_picture on the four report labels; "
                                  "cats: sound only, picture confirms a cat is in view"}

    out = {"model": "clip_vision_quantized.onnx", "source": MODEL_URL,
           "input": [1, 3, 224, 224], "input_name": emb.inp, "output": emb.out,
           "resize": "shortest side to 224 (bicubic), centre crop 224x224, RGB / 255", "mean": MEAN, "std": STD,
           "frames": "3 evenly spaced frames; average the embeddings, then scale to length 1",
           "gate": {"keys": [x[0] for x in GATE], "species": [x[1] for x in GATE], "prompts": [x[2] for x in GATE],
                    "scale": scale, "T": [[round(float(v), 7) for v in r] for r in T]},
           "dog_photo": clf, "combine": {"sound_weight": w}}
    json.dump(out, open(OUT, "w"))
    results["note"] = ("Dog photo labels are the uploader's, method not stated. Combine weight from held-out macro F1 "
                       "on separate datasets, not from paired clips.")
    json.dump(results, open(RESULTS, "w"), indent=1)
    print("STEP11_JSON", json.dumps({k: v for k, v in results.items() if k != "note"}, default=str))
    print(f"done in {time.time() - t0:.0f} s")


if __name__ == "__main__":
    main()
