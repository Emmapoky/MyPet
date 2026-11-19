"""MyPet ML step 13: video clips in the Test library (picture and sound, like the app's clip check).

Steps 5 to 8 filled the Test library with sounds. The app now records a short video, so this adds real
videos of dogs and cats from Wikimedia Commons (free licences), each checked the way the app does it:

  sound    loudest 10 s of the soundtrack -> CLAP -> sound evidence (which animal, which sound) and feeling
  picture  3 frames spread over the same 10 s -> 224x224 centre crop -> CLIP image model -> is a dog or cat
           in view, and for dogs the feeling from the picture
  combined for dogs: sound_weight * sound + (1 - sound_weight) * picture (photo_classifiers.json)

Videos come from the Commons categories below (files directly in each category), plus the videos already in
step 8's list. A video with no soundtrack is skipped, because the app always records sound.
Truth is the species of the category. Nobody labelled how these animals felt, so this tests the
"is it a dog or a cat" part with real footage, and shows what the feeling check says.

Run after tool/build_online_test.py and tool/build_photo_check.py:
  .venv/bin/python tool/build_video_library.py            # up to 40 videos per species
Writes assets/test_library/video_*.wav + video_*.rgb (3 raw 224x224 RGB frames), adds manifest entries with
"group": "video", and writes ml/results/13_video_clips.json.
"""
import hashlib, json, os, sys, time, urllib.parse, urllib.request
from collections import Counter

import numpy as np
from PIL import Image
from scipy.io import wavfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_test_library as base  # noqa: E402
import build_online_test as online  # noqa: E402
import build_photo_check as photo  # noqa: E402

RESULTS = os.path.join(base.APP, "..", "..", "results", "13_video_clips.json")
CATEGORIES = {"dog": ["Videos of dogs", "Videos of dogs barking", "Videos of puppies"],
              "cat": ["Videos of cats", "Videos of cats meowing", "Videos of kittens", "Videos of hissing cats"]}
PER_SPECIES = 40


def category_videos(cat):
    q = urllib.parse.urlencode({"action": "query", "format": "json", "list": "categorymembers", "cmtype": "file",
                                "cmlimit": "200", "cmtitle": "Category:" + cat})
    time.sleep(1.0)
    try:
        r = json.load(urllib.request.urlopen(urllib.request.Request(
            "https://commons.wikimedia.org/w/api.php?" + q, headers=online.UA), timeout=60))
    except Exception as e:  # noqa: BLE001
        print(f"  category {cat}: {e}")
        return []
    return [m["title"][len("File:"):] for m in r.get("query", {}).get("categorymembers", [])
            if m["title"].lower().endswith((".webm", ".ogv", ".mp4", ".mov"))]


def frames_in_window(path, start_s, dur_s):
    """3 frames at 20%, 50% and 80% of the 10 s window, as 224x224 RGB (same crop as the app)."""
    import av
    want = [start_s + dur_s * f for f in (0.2, 0.5, 0.8)]
    got = []
    with av.open(path) as c:
        vs = next(s for s in c.streams if s.type == "video")
        for fr in c.decode(vs):
            t = float(fr.time or 0)
            if len(got) < 3 and t >= want[len(got)]:
                got.append(fr.to_image())
            if len(got) == 3:
                break
        if len(got) < 3:  # short video: take what we have, repeat the last one
            got += [got[-1]] * (3 - len(got)) if got else []
    out = []
    for im in got:
        im = im.convert("RGB")
        w, h = im.size
        s = 224 / min(w, h)
        im = im.resize((max(224, round(w * s)), max(224, round(h * s))), Image.BICUBIC)
        w, h = im.size
        l, t = (w - 224) // 2, (h - 224) // 2
        out.append(np.asarray(im.crop((l, t, l + 224, t + 224)), dtype=np.uint8))
    return out


def loudest_start(x):
    n = base.N_SAMPLES
    if len(x) <= n:
        return 0
    step = base.SR // 2
    e = np.concatenate([[0], np.cumsum(x ** 2)])
    return max(range(0, len(x) - n + 1, step), key=lambda s: e[s + n] - e[s])


def main():
    t0 = time.time()
    out_dir = base.OUT
    clf = json.load(open(os.path.join(out_dir, "classifiers.json")))
    se = json.load(open(os.path.join(out_dir, "sound_evidence.json")))
    pc = json.load(open(os.path.join(out_dir, "photo_classifiers.json")))
    T, scale, keys = np.array(se["T"]), se["scale"], se["keys"]
    sp_of = dict(zip(keys, se["species"]))
    G = np.array(pc["gate"]["T"])
    gsp = pc["gate"]["species"]
    w = pc["combine"]["sound_weight"]
    emb, iemb = base.Embedder(), photo.ImageEmbedder()

    titles = {sp: [] for sp in CATEGORIES}
    for sp, cats in CATEGORIES.items():
        for cat in cats:
            titles[sp] += [t for t in category_videos(cat) if t not in titles[sp]]
    for t, sp, _ in online.COMMONS:
        if t.lower().endswith((".webm", ".ogv", ".mp4")) and t not in titles[sp]:
            titles[sp].insert(0, t)
    print({sp: len(v) for sp, v in titles.items()}, "videos listed")
    for sp in titles:
        titles[sp] = titles[sp][:PER_SPECIES * 2]  # extra in case some have no sound
    info = online.commons_info([t for v in titles.values() for t in v])

    manifest = [m for m in json.load(open(os.path.join(out_dir, "manifest.json"))) if m.get("group") != "video"]
    rows, skipped = [], []
    for sp, ts in titles.items():
        kept = 0
        for i, title in enumerate(ts):
            if kept >= PER_SPECIES:
                break
            if title not in info:
                skipped.append(f"{title}: not found")
                continue
            ext = os.path.splitext(info[title]["url"])[1]
            path = os.path.join(base.CACHE, "commons_video", f"{sp}_{hashlib.md5(title.encode()).hexdigest()[:10]}{ext}")
            try:
                online.get(info[title]["url"], path, polite=3.0)
                x = online.decode_any(path)
            except StopIteration:
                skipped.append(f"{title}: no soundtrack")
                continue
            except Exception as e:  # noqa: BLE001
                skipped.append(f"{title}: {str(e)[:60]}")
                continue
            if len(x) < base.SR // 2 or np.abs(x).max() < 1e-3:
                skipped.append(f"{title}: no sound")
                continue
            s0 = loudest_start(x)
            x10 = x[s0:s0 + base.N_SAMPLES]
            try:
                frames = frames_in_window(path, s0 / base.SR, len(x10) / base.SR)
            except Exception as e:  # noqa: BLE001
                skipped.append(f"{title}: frames {str(e)[:40]}")
                continue
            if len(frames) != 3:
                skipped.append(f"{title}: no frames")
                continue
            name = f"video_{sp}_{kept:03d}"
            pcm = base.to_pcm16(x10)
            wavfile.write(os.path.join(out_dir, name + ".wav"), base.SR, pcm)
            np.stack(frames).tofile(os.path.join(out_dir, name + ".rgb"))
            e = emb(base.from_pcm16(pcm))
            ps = base.sound_probs(T, scale, e)
            by = {s: sum(p for p, k in zip(ps, keys) if sp_of[k] == s) for s in set(sp_of.values())}
            fe = [iemb(Image.fromarray(f)) for f in frames]
            v = np.mean(fe, 0)
            v = v / np.linalg.norm(v)
            pg = base.sound_probs(G, pc["gate"]["scale"], v)
            gby = {s: sum(p for p, k in zip(pg, gsp) if k == s) for s in set(gsp)}
            task = "cat_context" if sp == "cat" else "dog_report"
            pf = base.probs(clf[task], e)
            py = {task: [round(float(q), 5) for q in pf], "sound": [round(float(q), 5) for q in ps],
                  "picture_gate": [round(float(q), 5) for q in pg]}
            pic_sp = max(gby, key=gby.get)
            if sp == "dog":
                pp = base.probs(pc["dog_photo"], v)
                py["dog_photo"] = [round(float(q), 5) for q in pp]
                if pic_sp == "dog":
                    pf = w * pf + (1 - w) * pp
                py["combined"] = [round(float(q), 5) for q in pf]
            rows.append({"species": sp, "sound_species": max(by, key=by.get), "picture_species": pic_sp,
                         "top_sound": keys[int(ps.argmax())], "feeling": clf[task]["classes"][int(pf.argmax())]})
            manifest.append({"file": name + ".wav", "frames": name + ".rgb", "species": sp, "group": "video",
                             "animal": "Video: " + title[:60], "truth": {}, "tasks": [task], "sound_truth": None,
                             "python": py, "seconds": round(len(pcm) / base.SR, 2),
                             "source": f"Wikimedia Commons, {info[title]['licence']}, {info[title]['page']}"})
            kept += 1
            print(f"  {name}: sound says {rows[-1]['sound_species']}, picture says {pic_sp}, "
                  f"top sound {rows[-1]['top_sound']}, feeling {rows[-1]['feeling']}", flush=True)
    json.dump(manifest, open(os.path.join(out_dir, "manifest.json"), "w"))

    def n(f):
        return sum(1 for r in rows if f(r))
    res = {"videos": len(rows), "dogs": n(lambda r: r["species"] == "dog"), "cats": n(lambda r: r["species"] == "cat"),
           "species_from_sound_right": n(lambda r: r["sound_species"] == r["species"]),
           "species_from_picture_right": n(lambda r: r["picture_species"] == r["species"]),
           "both_right": n(lambda r: r["sound_species"] == r["species"] == r["picture_species"]),
           "either_right": n(lambda r: r["species"] in (r["sound_species"], r["picture_species"])),
           "by_species": {sp: {"videos": n(lambda r, sp=sp: r["species"] == sp),
                               "sound_right": n(lambda r, sp=sp: r["species"] == sp == r["sound_species"]),
                               "picture_right": n(lambda r, sp=sp: r["species"] == sp == r["picture_species"]),
                               "picture_said": dict(Counter(r["picture_species"] for r in rows if r["species"] == sp)),
                               "top_sounds": dict(Counter(r["top_sound"] for r in rows if r["species"] == sp).most_common()),
                               "feeling": dict(Counter(r["feeling"] for r in rows if r["species"] == sp).most_common())}
                          for sp in ["dog", "cat"]},
           "skipped": skipped}
    json.dump(res, open(RESULTS, "w"), indent=1)
    mb = sum(os.path.getsize(os.path.join(out_dir, f)) for f in os.listdir(out_dir)) / 1e6
    print(f"{len(rows)} videos added; skipped {len(skipped)}; test library now {mb:.0f} MB")
    print("STEP13_JSON", json.dumps({k: v for k, v in res.items() if k != "skipped"}))
    print(f"done in {time.time() - t0:.0f} s")


if __name__ == "__main__":
    main()
