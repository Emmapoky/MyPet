"""MyPet ML step 8: test the phone's model on cat and dog recordings and videos found online.

The datasets in steps 1 to 7 were recorded by researchers. This step checks the same model on clips
recorded by ordinary people, with phones and cameras, in ordinary rooms and streets:

  Wikimedia Commons  free-licence audio AND video files of dogs and cats, labelled by sound type
                     (barking, growling, howling or whimpering, meowing, purring, hissing).
                     The list is fixed below so the test is repeatable; titles were picked from the
                     Commons categories "Dogs barking", "Audio files of Canis lupus", "Dogs howling",
                     "Audio files of cats meowing / purring / hissing", "Videos of hissing cats" and
                     "Cats meowing", leaving out wolves, word pronunciations and unrelated sounds.
  ESC-50             the 40 "dog" and 40 "cat" clips (Piczak 2015, Freesound recordings, CC BY-NC),
                     5 s each, labelled by species only.

Nobody labelled these clips with an emotion, so this is not an accuracy test of the emotion. It checks:
  1. does the sound evidence name the right animal and the right sound type?
  2. what does the emotion classifier say for each sound type (e.g. hissing should lean to "stressed")?

Run after tool/build_test_library.py --sound-evidence (it reuses that step's classifiers):
  .venv/bin/pip install av
  .venv/bin/python tool/build_online_test.py
Adds the online clips to assets/test_library/ (manifest entries with "group": "online") and writes
ml/results/08_online_clips.json.
"""
import csv, io, json, os, sys, time, urllib.error, urllib.parse, urllib.request
from collections import Counter, defaultdict

import numpy as np
from scipy.io import wavfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_test_library as base  # noqa: E402  (same pipeline, same classifiers)

CACHE = os.path.join(base.CACHE, "online")
RESULTS = os.path.join(base.APP, "..", "..", "results", "08_online_clips.json")
# Wikimedia's User-Agent policy asks for a way to reach the project.
UA = {"User-Agent": "MyPet-student-project/0.1 (https://github.com/Emmapoky/MyPet; FIT3162 university project) python-urllib"}
COMMONS_BLOCKED = {"n": 0}  # consecutive 429s; after 3 we stop asking Commons in this run

# (Commons file title, species, sound type). Sound types match the keys in base.SOUNDS.
COMMONS = [
    ("Barking of a dog.ogg", "dog", "dog_bark"),
    ("Barking of a dog 2.ogg", "dog", "dog_bark"),
    ("Bellender Zwergspitz.webm", "dog", "dog_bark"),
    ("Dog barking.webm", "dog", "dog_bark"),
    ("Imbir - szczeknięcie.webm", "dog", "dog_bark"),
    ("Labrador barking on command.theora.ogv", "dog", "dog_bark"),
    ("Perro ladrando.ogg", "dog", "dog_bark"),
    ("Rottweiler Barking.oga", "dog", "dog_bark"),
    ("Seis perros ladrando.wav", "dog", "dog_bark"),
    ("A dog making noises and barking.flac", "dog", "dog_bark"),
    ("Barking dog in Rome.ogg", "dog", "dog_bark"),
    ("Perro labrador ladrando 01.ogg", "dog", "dog_bark"),
    ("Perro labrador ladrando 02.ogg", "dog", "dog_bark"),
    ("Perro ladrar.ogg", "dog", "dog_bark"),
    ("Perros (Ligeti y Malena) ladrando.wav", "dog", "dog_bark"),
    ("Perros ladrando.wav", "dog", "dog_bark"),
    ("Sound-of-dog.ogg", "dog", "dog_bark"),
    ("Ladridos y perros jugando.wav", "dog", "dog_bark"),
    ("Shiba hond die wil wandelen, -Oct, 2012 a.ogv", "dog", "dog_whimper"),
    ("Perros peleando.ogg", "dog", "dog_growl"),
    ("Madsen-audio-01.flac", "dog", "dog_growl"),
    ("Perro pequeño gruñendo.wav", "dog", "dog_growl"),
    ("Dogs'-Expectation-about-Signalers'-Body-Size-by-Virtue-of-Their-Growls-pone.0015175.s005.ogg", "dog", "dog_growl"),
    ("Dogs'-Expectation-about-Signalers'-Body-Size-by-Virtue-of-Their-Growls-pone.0015175.s006.ogg", "dog", "dog_growl"),
    ("Dogs'-Expectation-about-Signalers'-Body-Size-by-Virtue-of-Their-Growls-pone.0015175.s007.ogg", "dog", "dog_growl"),
    ("Dog whimpering.webm", "dog", "dog_whimper"),
    ("Howling Husky Dog.webm", "dog", "dog_howl"),
    ("Audio file of cat meowing.ogg", "cat", "cat_meow"),
    ("Felis silvestris catus meows.ogg", "cat", "cat_meow"),
    ("Felis silvestris catus.ogg", "cat", "cat_meow"),
    ("GettingOutImpatient.ogg", "cat", "cat_meow"),
    ("Maullido de gata hembra joven.ogg", "cat", "cat_meow"),
    ("Meow domestic cat.ogg", "cat", "cat_meow"),
    ("Meow normalized.opus", "cat", "cat_meow"),
    ("Meow of a pleading cat.oga", "cat", "cat_meow"),
    ("Meow of a Siamese cat - freemaster2.wav", "cat", "cat_meow"),
    ("Meow.ogg", "cat", "cat_meow"),
    ("Miaulementcornisg.ogg", "cat", "cat_meow"),
    ("NoTrip.ogg", "cat", "cat_meow"),
    ("Weibliche Britisch Kurzhaar will Futter C1277 MIAUEN.wav", "cat", "cat_meow"),
    ("2015-11-24.νιαούρισμα.Νιάου.noise reduced.flac", "cat", "cat_meow"),
    ("Socks Clinton meow.wav", "cat", "cat_meow"),
    ("Green eyed cat.webm", "cat", "cat_meow"),
    ("2022-10-18 LJUBLJANA Doma CARNIVORA Felis catus DOMAČA MAČKA 4.webm", "cat", "cat_meow"),
    ("Cat making noises at the birds outside.webm", "cat", "cat_meow"),
    ("Bachgasse Wiki Lina Gebhardt and Anna Muck Cats Purring - Katzenschnurren.ogg", "cat", "cat_purr"),
    ("Cat in front of open fire purring.ogg", "cat", "cat_purr"),
    ("Cat purring (Mimi).ogg", "cat", "cat_purr"),
    ("Cat purring.ogg", "cat", "cat_purr"),
    ("Cat Purring.ogg", "cat", "cat_purr"),
    ("Felis silvestris catus purrs.ogg", "cat", "cat_purr"),
    ("Gatita (ronroneo).ogg", "cat", "cat_purr"),
    ("Jupey purring.wav", "cat", "cat_purr"),
    ("Purring and meowing.ogg", "cat", "cat_purr"),
    ("Purring cat bertie.ogg", "cat", "cat_purr"),
    ("Purring cat.oga", "cat", "cat_purr"),
    ("Ronroneo (Chabelita).ogg", "cat", "cat_purr"),
    ("Schnurren einer Hauskatze (schnell).ogg", "cat", "cat_purr"),
    ("Whiskers' purr.ogg", "cat", "cat_purr"),
    ("猫咪呼噜声.ogg", "cat", "cat_purr"),
    ("Cat hissing - Zabuhailo.wav", "cat", "cat_hiss"),
    ("Gruñido gato (Chacha).ogg", "cat", "cat_hiss"),
    ("Black and white cat growl and hiss.webm", "cat", "cat_hiss"),
    ("Black and white cat growl and hiss 2.webm", "cat", "cat_hiss"),
]
ESC50 = "https://raw.githubusercontent.com/karolpiczak/ESC-50/master/"


def get(url, path, polite=0.0):
    """Download once into the cache. Wikimedia asks bots to go slowly: with polite > 0 we wait that many
    seconds before each new download and back off on HTTP 429 (Too many requests)."""
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if polite and COMMONS_BLOCKED["n"] >= 3:
        raise RuntimeError("skipped: Commons is rate-limiting this run, try again later")
    for attempt in range(2):
        time.sleep(polite)
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=120) as r, open(path + ".part", "wb") as f:
                f.write(r.read())
            os.replace(path + ".part", path)
            COMMONS_BLOCKED["n"] = 0
            return path
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            if attempt == 1:
                COMMONS_BLOCKED["n"] += 1
                raise
            wait = min(int(e.headers.get("Retry-After") or 0) or 30, 130)
            print(f"  Commons asked us to slow down; waiting {wait} s", flush=True)
            time.sleep(wait)
    return path


def decode_any(path):
    """Audio track of any audio or video file -> 48 kHz mono float (PyAV bundles ffmpeg)."""
    import av
    out = []
    with av.open(path) as c:
        stream = next(s for s in c.streams if s.type == "audio")
        res = av.AudioResampler(format="flt", layout="mono", rate=base.SR)
        for frame in c.decode(stream):
            for f in res.resample(frame):
                out.append(f.to_ndarray().reshape(-1))
        for f in res.resample(None):
            out.append(f.to_ndarray().reshape(-1))
    return np.concatenate(out).astype(np.float64) if out else np.zeros(0)


def loudest_10s(x):
    """Recordings found online often start with silence or talking. Keep the 10 s window with the most
    energy (in 0.5 s steps), so the clip holds the animal. The app's own recordings are 10 s already."""
    n = base.N_SAMPLES
    if len(x) <= n:
        return x
    step = base.SR // 2
    e = np.concatenate([[0], np.cumsum(x ** 2)])
    starts = range(0, len(x) - n + 1, step)
    best = max(starts, key=lambda s: e[s + n] - e[s])
    return x[best:best + n]


def commons_info(titles):
    """URL, licence and author for each file, 40 titles per API call."""
    info = {}
    for i in range(0, len(titles), 40):
        q = urllib.parse.urlencode({"action": "query", "format": "json", "prop": "imageinfo",
                                    "iiprop": "url|extmetadata|mime", "titles": "|".join("File:" + t for t in titles[i:i + 40])})
        r = json.load(urllib.request.urlopen(urllib.request.Request("https://commons.wikimedia.org/w/api.php?" + q, headers=UA)))
        norm = {n["to"]: n["from"] for n in r["query"].get("normalized", [])}
        for p in r["query"]["pages"].values():
            if "imageinfo" not in p:
                continue
            ii = p["imageinfo"][0]
            meta = ii.get("extmetadata", {})
            t = norm.get(p["title"], p["title"])[len("File:"):]
            info[t] = {"url": ii["url"], "mime": ii.get("mime", ""),
                       "licence": meta.get("LicenseShortName", {}).get("value", "?"),
                       "page": "https://commons.wikimedia.org/wiki/" + urllib.parse.quote(p["title"].replace(" ", "_"))}
    return info


def main():
    t0 = time.time()
    out_dir = base.OUT
    clf = {k: v for k, v in json.load(open(os.path.join(out_dir, "classifiers.json"))).items()}
    se = json.load(open(os.path.join(out_dir, "sound_evidence.json")))
    T, scale, keys = np.array(se["T"]), se["scale"], se["keys"]
    sp_of = dict(zip(keys, se["species"]))
    emb = base.Embedder()

    clips, skipped = [], []
    info = commons_info([t for t, _, _ in COMMONS])
    for i, (title, species, sound) in enumerate(COMMONS):
        if title not in info:
            skipped.append(f"{title}: not found on Commons")
            continue
        ext = os.path.splitext(info[title]["url"])[1]
        try:
            x = decode_any(get(info[title]["url"], os.path.join(CACHE, "commons", f"{i:03d}{ext}"), polite=3.0))
        except Exception as e:  # noqa: BLE001
            skipped.append(f"{title}: {str(e)[:60]}")
            continue
        if len(x) < base.SR // 4:
            skipped.append(f"{title}: no audio")
            continue
        clips.append({"name": f"online_commons_{i:03d}", "species": species, "sound": sound, "x": loudest_10s(x),
                      "video": info[title]["mime"].startswith("video"), "title": title,
                      "source": f"Wikimedia Commons, {info[title]['licence']}, {info[title]['page']}"})
    meta = get(ESC50 + "meta/esc50.csv", os.path.join(CACHE, "esc50", "esc50.csv"))
    for row in csv.DictReader(open(meta)):
        if row["category"] not in ("dog", "cat"):
            continue
        p = get(ESC50 + "audio/" + row["filename"], os.path.join(CACHE, "esc50", row["filename"]))
        clips.append({"name": "online_esc50_" + row["filename"][:-4], "species": row["category"], "sound": None,
                      "x": base.read_wav_48k(open(p, "rb").read()), "video": False, "title": row["filename"],
                      "source": "ESC-50 (Piczak 2015), Freesound recording, CC BY-NC"})

    manifest = [m for m in json.load(open(os.path.join(out_dir, "manifest.json"))) if m.get("group") != "online"]
    rows = []
    for c in clips:
        pcm = base.to_pcm16(c["x"])
        wavfile.write(os.path.join(out_dir, c["name"] + ".wav"), base.SR, pcm)
        x = emb(base.from_pcm16(pcm))
        ps = base.sound_probs(T, scale, x)
        task = "cat_context" if c["species"] == "cat" else "dog_report"
        pe = base.probs(clf[task], x)
        by = defaultdict(float)
        for k, p in zip(keys, ps):
            by[sp_of[k]] += p
        top = keys[int(ps.argmax())]
        rows.append({"species": c["species"], "sound": c["sound"], "video": c["video"],
                     "species_ok": max(by, key=by.get) == c["species"],
                     "sound_ok": None if c["sound"] is None else top == c["sound"], "top_sound": top,
                     "feeling": clf[task]["classes"][int(pe.argmax())]})
        manifest.append({"file": c["name"] + ".wav", "species": c["species"], "group": "online",
                         "animal": ("Video: " if c["video"] else "") + c["title"][:60], "truth": {},
                         "tasks": [task], "sound_truth": c["sound"],
                         "python": {task: [round(float(v), 5) for v in pe], "sound": [round(float(v), 5) for v in ps]},
                         "seconds": round(len(pcm) / base.SR, 2), "source": c["source"]})
    json.dump(manifest, open(os.path.join(out_dir, "manifest.json"), "w"))

    res = {"clips": len(rows), "commons": sum(r["sound"] is not None for r in rows),
           "commons_videos": sum(r["video"] for r in rows), "esc50": sum(r["sound"] is None for r in rows),
           "skipped": skipped,
           "species_from_sound_right": sum(r["species_ok"] for r in rows),
           "sound_type_right": sum(bool(r["sound_ok"]) for r in rows if r["sound"] is not None),
           "by_sound_type": {}}
    for s in sorted({r["sound"] or f"esc50_{r['species']}" for r in rows}):
        rs = [r for r in rows if (r["sound"] or f"esc50_{r['species']}") == s]
        res["by_sound_type"][s] = {"clips": len(rs), "species_right": sum(r["species_ok"] for r in rs),
                                   "sound_right": sum(bool(r["sound_ok"]) for r in rs),
                                   "top_sounds": dict(Counter(r["top_sound"] for r in rs).most_common()),
                                   "feeling": dict(Counter(r["feeling"] for r in rs).most_common())}
    json.dump(res, open(RESULTS, "w"), indent=1)
    print(f"{res['clips']} online clips ({res['commons']} Commons incl. {res['commons_videos']} videos, "
          f"{res['esc50']} ESC-50); skipped {len(skipped)}: {skipped}")
    print(f"species from sound right: {res['species_from_sound_right']}/{res['clips']}; "
          f"sound type right: {res['sound_type_right']}/{res['commons']}")
    for s, v in res["by_sound_type"].items():
        print(f"  {s:12s} n={v['clips']:3d} species {v['species_right']:3d} sound {v['sound_right']:3d} "
              f"top {v['top_sounds']} feeling {v['feeling']}")
    print("STEP8_JSON", json.dumps({k: v for k, v in res.items() if k != "skipped"}))
    print(f"done in {time.time() - t0:.0f} s")


if __name__ == "__main__":
    main()
