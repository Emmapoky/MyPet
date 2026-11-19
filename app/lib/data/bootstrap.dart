import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:path_provider/path_provider.dart';

import '../firebase_options.dart';
import 'backend.dart';
import 'firestore_backend.dart';
import 'local_backend.dart';

/// Which backend to start with. Pass --dart-define=BACKEND=firebase once
/// docs/firebase-setup.md is done; the default keeps everything on the phone.
const backendChoice = String.fromEnvironment('BACKEND', defaultValue: 'local');

Future<Backend> startBackend() async {
  if (backendChoice == 'firebase') {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    return FirestoreBackend();
  }
  final dir = await getApplicationDocumentsDirectory();
  final b = LocalBackend(file: File('${dir.path}/mypet_local.json'));
  await b.load();
  return b;
}
