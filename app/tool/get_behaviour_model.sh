#!/bin/sh
# Puts the behaviour check's model files into assets/ before a build.
#   1. The quantized CLAP audio encoder (34.3 MB, Apache 2.0) and the CLIP image
#      encoder (about 90 MB, MIT), downloaded.
#   2. classifiers.json and sound_evidence.json, copied from the ML bench.
#      Build them first on the Mac with:
#        cd ml/flutter/behaviour_bench && .venv/bin/python tool/build_test_library.py --sound-evidence
# None of these are committed to git.
set -e
APP="$(cd "$(dirname "$0")/.." && pwd)"
BENCH="$APP/../ml/flutter/behaviour_bench"
mkdir -p "$APP/assets/models" "$APP/assets/behaviour"

if [ -f "$BENCH/assets/models/clap_audio_quantized.onnx" ]; then
  cp "$BENCH/assets/models/clap_audio_quantized.onnx" "$APP/assets/models/"
elif [ ! -f "$APP/assets/models/clap_audio_quantized.onnx" ]; then
  curl -L --fail -o "$APP/assets/models/clap_audio_quantized.onnx" \
    https://huggingface.co/Xenova/clap-htsat-unfused/resolve/main/onnx/audio_model_quantized.onnx
fi

# Picture model (ML step 11): CLIP ViT-B/32 image encoder, quantized (MIT), about 90 MB.
# Prefer the ML Lab's copy so the picture classifiers match the exact model they were trained on.
if [ -f "$BENCH/assets/models/clip_vision_quantized.onnx" ]; then
  cp "$BENCH/assets/models/clip_vision_quantized.onnx" "$APP/assets/models/"
elif [ ! -f "$APP/assets/models/clip_vision_quantized.onnx" ]; then
  curl -L --fail -o "$APP/assets/models/clip_vision_quantized.onnx" \
    https://huggingface.co/Xenova/clip-vit-base-patch32/resolve/main/onnx/vision_model_quantized.onnx
fi
# Optional: without photo_classifiers.json the check uses sound only.
if [ -f "$BENCH/assets/test_library/photo_classifiers.json" ]; then
  cp "$BENCH/assets/test_library/photo_classifiers.json" "$APP/assets/behaviour/"
else
  echo "No photo_classifiers.json yet (ML step 11): the app will use sound only."
fi

for f in classifiers.json sound_evidence.json; do
  if [ ! -f "$BENCH/assets/test_library/$f" ]; then
    echo "Missing $BENCH/assets/test_library/$f. Build it with build_test_library.py --sound-evidence first." >&2
    exit 1
  fi
  cp "$BENCH/assets/test_library/$f" "$APP/assets/behaviour/"
done
ls -l "$APP/assets/models" "$APP/assets/behaviour"
