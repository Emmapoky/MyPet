# clap_features (Dart)

Turns a mono 48 kHz recording into the input for the CLAP ONNX model (`input_features`, [1, 1, 1001, 64]).
Pure Dart with no packages, so the Flutter app can use it as a path dependency and run it in an isolate.
Port of `ml/reference/clap_features.py`.

```dart
import 'package:clap_features/clap_features.dart';
final features = clapInputFeatures(samples); // Float32List, 1001 * 64
```

Test (checks against `ml/reference/fixtures`): `cd ml/dart/clap_features && dart pub get && dart test`

Result on 19 Nov 2026 (Dart 3.14.1): filter bank within 1e-9, features within 0.00001 dB of the reference on all three test signals; about 0.15 s per clip on a laptop-class CPU.
