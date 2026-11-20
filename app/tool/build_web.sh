#!/bin/sh
# Builds the MyPet web test build into app/build/web, ready for web_host/ (Cloudflare).
#   1. Model files as for the phone (tool/get_behaviour_model.sh) must be in assets/.
#   2. flutter build web, then the models move out of the Flutter assets into
#      build/web/models/ in parts under 25 MiB (Cloudflare's per-file limit);
#      web_host/worker.js joins them back.
#   3. ONNX Runtime Web 1.20.1 (MIT) is copied from npm into build/web/ort/.
# The phone builds are not affected by any of this.
set -e
APP="$(cd "$(dirname "$0")/.." && pwd)"
cd "$APP"
for f in assets/models/clap_audio_quantized.onnx assets/models/clip_vision_quantized.onnx \
         assets/behaviour/classifiers.json assets/behaviour/sound_evidence.json; do
  [ -f "$f" ] || { echo "Missing $f. Run tool/get_behaviour_model.sh first." >&2; exit 1; }
done

rm -rf build/web
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn
OUT="$APP/build/web"
rm -f "$OUT"/assets/assets/models/*.onnx

mkdir -p "$OUT/models"
python3 - "$APP/assets/models" "$OUT/models" <<'PY'
import json, os, sys
src, out = sys.argv[1], sys.argv[2]
part = 20 * 1024 * 1024
listing = {}
for name in ("clap_audio_quantized.onnx", "clip_vision_quantized.onnx"):
    data = open(os.path.join(src, name), "rb").read()
    parts = []
    for i in range(0, len(data), part):
        p = f"{name}.part{i // part}"
        open(os.path.join(out, p), "wb").write(data[i:i + part])
        parts.append(p)
    listing[name] = {"size": len(data), "parts": parts}
json.dump(listing, open(os.path.join(out, "parts.json"), "w"), indent=1)
print("models:", {k: len(v["parts"]) for k, v in listing.items()})
PY

TMP="$(mktemp -d)"
(cd "$TMP" && npm pack --silent onnxruntime-web@1.20.1 >/dev/null && tar xzf onnxruntime-web-1.20.1.tgz)
mkdir -p "$OUT/ort"
cp "$TMP"/package/dist/ort.wasm.min.js "$TMP"/package/dist/ort-wasm-simd-threaded.wasm \
   "$TMP"/package/dist/ort-wasm-simd-threaded.mjs "$OUT/ort/"
rm -rf "$TMP"
du -sh "$OUT"
echo "Built. Deploy: cd web_host && npx wrangler deploy"
