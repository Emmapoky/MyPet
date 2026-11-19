"""MyPet ML step 14: demo clips for the app (real videos, cut, credited, with the check's answer).

The app's demo shows example pets with real video clips already loaded. This picks 8 to 10 of the videos
from step 13 (Wikimedia Commons, redistribution-friendly licences only: CC0, CC BY, CC BY-SA, public domain),
cuts the strongest 6 to 10 s, re-encodes them small (H.264 + AAC, short side 480 px, at most 1.2 MB each)
and writes clips.json with, for each clip, the credits and what the check says on exactly that cut:

  overall   feeling + likelihood (dogs: sound and picture combined; cats: sound only), top 3 sounds,
            whether the picture shows the pet
  moments   per second, sound and picture, in the app's Moment.toJson shape {src, label, s, e, p}

Spread wanted: dogs barking, whimpering or whining, calm or playful dogs; cats meowing, purring, hissing;
a puppy or kitten if one is there. Run after tool/build_video_library.py (it reuses the downloads):

  .venv/bin/pip install imageio-ffmpeg        # only if `ffmpeg` is not already installed
  .venv/bin/python tool/make_demo_clips.py

Writes ml/demo-clips/*.mp4 and ml/demo-clips/clips.json.
"""
import hashlib, html, json, os, re, shutil, subprocess, sys, time, urllib.parse, urllib.request

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_test_library as base  # noqa: E402
import build_online_test as online  # noqa: E402
import build_photo_check as photo  # noqa: E402
import build_video_library as vid  # noqa: E402

OUT = os.path.join(base.APP, "..", "..", "demo-clips")
MAX_BYTES = 1_200_000
ALLOWED = re.compile(r"^(CC0|CC BY(-SA)? [0-9.]+|CC BY(-SA)?|Public domain|PD.*)$", re.I)
WANT = [  # (slot, species, test on the clip, how many)
    ("dog_bark", "dog", lambda r: r["top_sound"] == "dog_bark", lambda r: r["sound_p"], 3),
    ("dog_whimper", "dog", lambda r: r["top_sound"] in ("dog_whimper", "dog_howl"), lambda r: r["sound_p"], 1),
    ("dog_calm_or_playful", "dog", lambda r: r["feeling"] in ("calm", "happy") and r["top_sound"] != "dog_bark",
     lambda r: r["feeling_p"], 2),
    ("cat_meow", "cat", lambda r: r["top_sound"] == "cat_meow", lambda r: r["sound_p"], 2),
    ("cat_purr", "cat", lambda r: r["top_sound"] == "cat_purr", lambda r: r["sound_p"], 1),
    ("cat_hiss", "cat", lambda r: r["top_sound"] == "cat_hiss", lambda r: r["sound_p"], 1),
]


def ffmpeg_exe():
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def authors(titles):
    out = {}
    for i in range(0, len(titles), 40):
        q = urllib.parse.urlencode({"action": "query", "format": "json", "prop": "imageinfo", "iiprop": "extmetadata",
                                    "titles": "|".join("File:" + t for t in titles[i:i + 40])})
        time.sleep(1.0)
        r = json.load(urllib.request.urlopen(urllib.request.Request(
            "https://commons.wikimedia.org/w/api.php?" + q, headers=online.UA), timeout=60))
        norm = {n["to"]: n["from"] for n in r["query"].get("normalized", [])}
        for p in r["query"]["pages"].values():
            if "imageinfo" in p:
                a = p["imageinfo"][0].get("extmetadata", {}).get("Artist", {}).get("value", "")
                out[norm.get(p["title"], p["title"])[len("File:"):]] = html.unescape(re.sub(r"<[^>]+>", "", a)).strip() or "Unknown"
    return out


def frames_at(path, times):
    """RGB PIL frames nearest to each time (s), decoded in order."""
    import av
    got, i = [], 0
    last = None
    with av.open(path) as c:
        vs = next(s for s in c.streams if s.type == "video")
        for fr in c.decode(vs):
            t = float(fr.time or 0)
            last = fr
            while i < len(times) and t >= times[i]:
                got.append(fr.to_image())
                i += 1
            if i == len(times):
                break
    while len(got) < len(times) and last is not None:
        got.append(last.to_image())
    return got


def analyse(path, x, s0, dur, ctx):
    emb, iemb, T, scale, keys, names, sp_of, clf, pc, G, gsp, w = ctx
    seg = x[int(s0 * base.SR):int((s0 + dur) * base.SR)]
    pcm = base.to_pcm16(seg[:base.N_SAMPLES])
    e = emb(base.from_pcm16(pcm))
    ps = base.sound_probs(T, scale, e)
    order = np.argsort(-ps)
    frames = frames_at(path, [s0 + dur * f for f in (0.2, 0.5, 0.8)])
    v = np.mean([iemb(f) for f in frames], 0)
    v /= np.linalg.norm(v)
    pg = base.sound_probs(G, pc["gate"]["scale"], v)
    gby = {s: float(sum(p for p, k in zip(pg, gsp) if k == s)) for s in set(gsp)}
    pic_sp = max(gby, key=gby.get)
    return e, ps, order, v, pg, gby, pic_sp, frames


def moments(path, x, s0, dur, ctx, species):
    emb, iemb, T, scale, keys, names, sp_of, clf, pc, G, gsp, w = ctx
    out = []
    secs = int(dur)
    fr = frames_at(path, [s0 + k + 0.5 for k in range(secs)])
    for k in range(secs):
        a = int((s0 + max(0, k - 0.5)) * base.SR)
        b = int((s0 + k + 1.5) * base.SR)  # 2 s window around the second
        e = emb(base.from_pcm16(base.to_pcm16(x[a:b])))
        ps = base.sound_probs(T, scale, e)
        j = int(ps.argmax())
        out.append({"src": "sound", "label": names[j], "s": float(k), "e": float(k + 1), "p": round(float(ps[j]), 3)})
        v = iemb(fr[k])
        pg = base.sound_probs(G, pc["gate"]["scale"], v)
        j = int(pg.argmax())
        out.append({"src": "picture", "label": pc["gate"]["prompts"][j].replace("a photo of ", ""), "s": float(k),
                    "e": float(k + 1), "p": round(float(pg[j]), 3)})
    return out


def encode(src, s0, dur, dst):
    exe = ffmpeg_exe()
    vf = "scale='if(gt(iw,ih),-2,480)':'if(gt(iw,ih),480,-2)',fps=24"
    for crf, ab in [(27, "64k"), (30, "56k"), (33, "48k"), (36, "40k"), (39, "32k")]:
        subprocess.run([exe, "-y", "-loglevel", "error", "-ss", f"{s0:.2f}", "-t", f"{dur:.2f}", "-i", src,
                        "-vf", vf, "-c:v", "libx264", "-preset", "slow", "-crf", str(crf), "-pix_fmt", "yuv420p",
                        "-c:a", "aac", "-b:a", ab, "-ac", "1", "-movflags", "+faststart", dst], check=True)
        if os.path.getsize(dst) <= MAX_BYTES:
            return True
    return os.path.getsize(dst) <= MAX_BYTES


def main():
    t0 = time.time()
    lib = base.OUT
    clf = json.load(open(os.path.join(lib, "classifiers.json")))
    se = json.load(open(os.path.join(lib, "sound_evidence.json")))
    pc = json.load(open(os.path.join(lib, "photo_classifiers.json")))
    T, scale, keys, names = np.array(se["T"]), se["scale"], se["keys"], se["names"]
    sp_of = dict(zip(keys, se["species"]))
    G, gsp, w = np.array(pc["gate"]["T"]), pc["gate"]["species"], pc["combine"]["sound_weight"]
    ctx = (base.Embedder(), photo.ImageEmbedder(), T, scale, keys, names, sp_of, clf, pc, G, gsp, w)
    emb = ctx[0]

    titles = {sp: [] for sp in vid.CATEGORIES}
    for sp, cats in vid.CATEGORIES.items():
        for cat in cats:
            titles[sp] += [t for t in vid.category_videos(cat) if t not in titles[sp]]
    for t, sp, _ in online.COMMONS:
        if t.lower().endswith((".webm", ".ogv", ".mp4")) and t not in titles[sp]:
            titles[sp].insert(0, t)
    allt = [t for v in titles.values() for t in v]
    info = online.commons_info(allt)

    cands = []
    for sp, ts in titles.items():
        for title in ts:
            if title not in info or not ALLOWED.match(info[title]["licence"].strip()):
                continue
            ext = os.path.splitext(info[title]["url"])[1]
            path = os.path.join(base.CACHE, "commons_video", f"{sp}_{hashlib.md5(title.encode()).hexdigest()[:10]}{ext}")
            if not os.path.exists(path):  # only what step 13 already downloaded
                continue
            try:
                x = online.decode_any(path)
            except Exception:  # noqa: BLE001
                continue
            if len(x) < 6 * base.SR or np.abs(x).max() < 1e-3:
                continue
            n = min(8 * base.SR, len(x))
            e = np.concatenate([[0], np.cumsum(x ** 2)])
            best = max(range(0, len(x) - n + 1, base.SR // 2), key=lambda s: e[s + n] - e[s])
            s0, dur = best / base.SR, n / base.SR
            try:
                _, ps, order, v, pg, gby, pic_sp, _ = analyse(path, x, s0, dur, ctx)
            except Exception as ex:  # noqa: BLE001
                print("  skip", title, str(ex)[:50])
                continue
            if pic_sp != sp:  # the picture must show the pet
                continue
            seg = x[int(s0 * base.SR):int((s0 + dur) * base.SR)][:base.N_SAMPLES]
            ee = emb(base.from_pcm16(base.to_pcm16(seg)))
            if sp_of[keys[int(order[0])]] != sp:  # the sound must also come from the pet, or the demo looks odd
                continue
            task = "cat_context" if sp == "cat" else "dog_report"
            pf = base.probs(clf[task], ee)
            if sp == "dog":
                pf = w * pf + (1 - w) * base.probs(pc["dog_photo"], v)
            j = int(pf.argmax())
            cands.append({"task": task, "pf": pf, "title": title, "species": sp, "path": path, "x": x, "s0": s0, "dur": dur,
                          "top_sound": keys[int(order[0])], "sound_p": float(ps[order[0]]),
                          "feeling": clf[task]["classes"][j], "feeling_p": float(pf[j]),
                          "feeling_name": clf[task]["names"][j], "ps": ps, "order": order, "pg": pg, "gby": gby,
                          "young": bool(re.search(r"pupp|kitten|pup\b|kitty", title, re.I)), "info": info[title]})
    print(len(cands), "candidate clips with an allowed licence and the pet in view")

    chosen, used = [], set()
    for slot, sp, ok, score, n in WANT:
        pool = sorted([c for c in cands if c["species"] == sp and c["title"] not in used and ok(c)],
                      key=lambda c: -score(c))[:n]
        for c in pool:
            c["slot"] = slot
            chosen.append(c)
            used.add(c["title"])
        if len(pool) < n:
            print(f"  slot {slot}: wanted {n}, found {len(pool)}")
    young = [c for c in cands if c["young"] and c["title"] not in used]
    if young and len(chosen) < 10:
        c = max(young, key=lambda c: c["sound_p"])
        c["slot"] = "puppy_or_kitten"
        chosen.append(c)
    by_author = authors([c["title"] for c in chosen])

    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        os.remove(os.path.join(OUT, f))
    meta = []
    for i, c in enumerate(chosen):
        name = f"{c['species']}_{c['slot']}_{i + 1:02d}.mp4"
        dst = os.path.join(OUT, name)
        if not encode(c["path"], c["s0"], c["dur"], dst):
            print("  too big even at the lowest quality:", name)
            os.remove(dst)
            continue
        mom = moments(c["path"], c["x"], c["s0"], c["dur"], ctx, c["species"])
        title = os.path.splitext(c["title"])[0].replace("_", " ")
        meta.append({
            "file": name, "species": c["species"], "slot": c["slot"], "title": title,
            "author": by_author.get(c["title"], "Unknown"), "licence": c["info"]["licence"], "page": c["info"]["page"],
            "seconds": round(c["dur"], 1), "bytes": os.path.getsize(dst),
            "result": {
                "feeling": c["feeling"], "feeling_name": c["feeling_name"], "p": round(c["feeling_p"], 3),
                "feelings": {n: round(float(q), 3) for n, q in zip(clf[c["task"]]["names"], c["pf"])},
                "method": "sound and picture combined" if c["species"] == "dog" else "sound only (cat feelings come from meows)",
                "top_sounds": [{"key": keys[int(j)], "name": names[int(j)], "p": round(float(c["ps"][j]), 3)} for j in c["order"][:3]],
                "picture_shows_pet": True,
                "picture": {"what": pc["gate"]["prompts"][int(c["pg"].argmax())].replace("a photo of ", ""),
                            "p": round(float(c["pg"].max()), 3),
                            "species_likelihood": {k: round(v, 3) for k, v in c["gby"].items()}},
            },
            "moments": mom})
        print(f"  {name}: {os.path.getsize(dst) / 1e6:.2f} MB, feeling {c['feeling']} {c['feeling_p']:.2f}, "
              f"top sound {c['top_sound']} {c['sound_p']:.2f}", flush=True)
    json.dump({"note": "Cuts of Wikimedia Commons videos under licences that allow redistribution. Results come from "
                       "the same pipeline as the app (CLAP sound, CLIP picture, sound weight from photo_classifiers.json). "
                       "Likelihoods only, not a diagnosis.",
               "clips": meta}, open(os.path.join(OUT, "clips.json"), "w"), indent=1, ensure_ascii=False)
    print(f"{len(meta)} demo clips, {sum(m['bytes'] for m in meta) / 1e6:.1f} MB in total ({time.time() - t0:.0f} s)")
    print("DEMO_SUMMARY", json.dumps([[m["file"], m["licence"], m["result"]["feeling"], m["result"]["p"]] for m in meta]))


if __name__ == "__main__":
    main()
