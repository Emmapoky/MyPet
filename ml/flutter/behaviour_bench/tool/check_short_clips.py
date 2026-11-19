"""MyPet ML step 11b: does a 5 s clip work as well as a 10 s clip?

The app now records one clip of 5 to 10 s. A clip shorter than 10 s is repeat-padded to 10 s (report
Table 4.1). This takes every test-library clip longer than 5 s, keeps only its first 5 s, runs the phone
pipeline again, and compares with the 10 s answer: same animal from the sound, same sound type, same feeling,
and (where a true label exists) how many are right.

Run after tool/build_online_test.py:
  .venv/bin/python tool/check_short_clips.py
Writes ../../results/11_short_clips.json.
"""
import json, os, sys

import numpy as np
from scipy.io import wavfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_test_library as base  # noqa: E402

LIB = os.path.join(base.APP, "assets", "test_library")
RESULTS = os.path.join(base.APP, "..", "..", "results", "11_short_clips.json")


def main():
    man = json.load(open(os.path.join(LIB, "manifest.json")))
    clf = json.load(open(os.path.join(LIB, "classifiers.json")))
    se = json.load(open(os.path.join(LIB, "sound_evidence.json")))
    T, scale, keys, sp = np.array(se["T"]), se["scale"], se["keys"], se["species"]
    emb = base.Embedder()
    half = base.SR * 5
    rows = []
    for m in man:
        sr, pcm = wavfile.read(os.path.join(LIB, m["file"]))
        if len(pcm) <= half + base.SR // 2:
            continue
        task = (m.get("tasks") or list(m["truth"].keys()) or ["cat_context"])[0]
        task = "dog_report" if m["species"] == "dog" and task.startswith("dog") else task
        r = {"group": m.get("group", "dataset"), "species": m["species"], "sound_truth": m.get("sound_truth"),
             "truth": m["truth"].get(task)}
        for tag, x in [("s10", base.from_pcm16(pcm)), ("s5", base.from_pcm16(pcm[:half]))]:
            e = emb(x)
            ps = base.sound_probs(T, scale, e)
            by = {s: sum(p for p, s_ in zip(ps, sp) if s_ == s) for s in set(sp)}
            pf = base.probs(clf[task], e)
            r[tag] = {"species": max(by, key=by.get), "sound": keys[int(ps.argmax())],
                      "feeling": clf[task]["classes"][int(pf.argmax())], "top_p": float(pf.max())}
        rows.append(r)

    def count(rs):
        out = {"clips": len(rs)}
        for tag in ["s10", "s5"]:
            out[tag] = {"species_right": sum(r[tag]["species"] == r["species"] for r in rs),
                        "sound_right": sum(r[tag]["sound"] == r["sound_truth"] for r in rs if r["sound_truth"]),
                        "feeling_right": sum(r[tag]["feeling"] == r["truth"] for r in rs if r["truth"]),
                        "mean_top_likelihood": round(float(np.mean([r[tag]["top_p"] for r in rs])), 3) if rs else None}
        out["with_sound_label"] = sum(bool(r["sound_truth"]) for r in rs)
        out["with_feeling_label"] = sum(bool(r["truth"]) for r in rs)
        out["same_feeling_5s_vs_10s"] = sum(r["s5"]["feeling"] == r["s10"]["feeling"] for r in rs)
        out["same_species_5s_vs_10s"] = sum(r["s5"]["species"] == r["s10"]["species"] for r in rs)
        return out

    res = {"all": count(rows)}
    for g in sorted({r["group"] for r in rows}):
        res[g] = count([r for r in rows if r["group"] == g])
    lens = [len(wavfile.read(os.path.join(LIB, m["file"]))[1]) / base.SR for m in man]
    res["clip_seconds"] = {"total": len(lens), "over_5s": sum(s > 5.5 for s in lens),
                           "median": round(float(np.median(lens)), 2)}
    json.dump(res, open(RESULTS, "w"), indent=1)
    print("SHORT_JSON", json.dumps(res))


if __name__ == "__main__":
    main()
