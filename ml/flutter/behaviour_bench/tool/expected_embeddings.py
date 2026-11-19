"""Computes the expected embeddings for the bench's three test signals with Python + onnxruntime,
using the same NumPy reference features (ml/reference) and the same quantized ONNX file.
Writes assets/expected_embeddings.json. Needs: pip install numpy onnxruntime
Run from ml/flutter/behaviour_bench after tool/fetch_model.sh."""
import json, os, sys
import numpy as np, onnxruntime as ort
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(here, "..", "..", "..", "reference"))
from clap_features import clap_input_features, test_signal, TEST_SIGNALS
s = ort.InferenceSession(os.path.join(here, "..", "assets", "models", "clap_audio_quantized.onnx"), providers=["CPUExecutionProvider"])
out = {}
for name in TEST_SIGNALS:
    emb = s.run(["audio_embeds"], {"input_features": clap_input_features(test_signal(name))})[0][0]
    out[name] = [round(float(v), 6) for v in emb]
json.dump(out, open(os.path.join(here, "..", "assets", "expected_embeddings.json"), "w"))
print("wrote expected embeddings for", list(out))
