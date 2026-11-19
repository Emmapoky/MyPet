#!/bin/sh
# Downloads the models into assets/models/ (not committed to git because of their size):
#   clap_audio_quantized.onnx   CLAP audio encoder, 34.3 MB, Apache 2.0 (sound)
#   clip_vision_quantized.onnx  CLIP ViT-B/32 image encoder, 85 MB, MIT (picture, step 11)
set -e
cd "$(dirname "$0")/.."
mkdir -p assets/models
[ -f assets/models/clap_audio_quantized.onnx ] || curl -L --fail -o assets/models/clap_audio_quantized.onnx \
  https://huggingface.co/Xenova/clap-htsat-unfused/resolve/main/onnx/audio_model_quantized.onnx
[ -f assets/models/clip_vision_quantized.onnx ] || curl -L --fail -o assets/models/clip_vision_quantized.onnx \
  https://huggingface.co/Xenova/clip-vit-base-patch32/resolve/main/onnx/vision_model_quantized.onnx
ls -l assets/models/
