# behaviour_bench (ML step 3)

A tiny Flutter app that times MyPet's behaviour check on a real phone: from "10 s clip finished" to
"512-number embedding ready" (Dart features from `ml/dart/clap_features` in an isolate, then the quantized
CLAP ONNX model through `flutter_onnxruntime`). Target from the report: under 5 s (FR20, NFR03).
It also checks the phone's embeddings against Python's for the same test sounds.

## Run it (Mac with Flutter and Xcode)

```sh
cd ml/flutter/behaviour_bench
./tool/fetch_model.sh                       # downloads the 34.3 MB model (not in git)
python3 -m venv .venv && .venv/bin/pip install numpy onnxruntime
.venv/bin/python tool/expected_embeddings.py   # writes assets/expected_embeddings.json
flutter pub get
flutter run -d <iphone-id> --profile --dart-define=AUTORUN=true   # real phone: use --profile for real speed
```

Look for the `BENCH_JSON` line in the output. Simulators only run debug builds, which are much slower, so use
them to check it works, not for timing. iOS needs a minimum of 16.0 (set). With CocoaPods, the Podfile needs
`platform :ios, '16.0'` and `use_frameworks! :linkage => :static`.
