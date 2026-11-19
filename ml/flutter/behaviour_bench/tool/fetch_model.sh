#!/bin/sh
# Downloads the quantized CLAP audio encoder (34.3 MB, Apache 2.0) into assets/models/.
# Not committed to git because of its size.
set -e
cd "$(dirname "$0")/.."
mkdir -p assets/models
curl -L --fail -o assets/models/clap_audio_quantized.onnx \
  https://huggingface.co/Xenova/clap-htsat-unfused/resolve/main/onnx/audio_model_quantized.onnx
ls -l assets/models/clap_audio_quantized.onnx
