# MyPet web test build

A browser version of MyPet for testers, on phone or laptop. It lives on the `web`
branch and does not change how the iPhone, Mac or Android builds behave: every
web-only piece is picked by a conditional import (`dart.library.js_interop`), and
on the phone those imports resolve to exactly what was there before (`dart:io`,
`path_provider`, `PhoneBehaviourEngine`).

## What works in the browser

| Part | Web build |
| --- | --- |
| Logs, pets, reminders list, insights, change flags | Yes. Kept in the browser (localStorage), per visitor, nothing uploaded. |
| Try a demo (stories, demo clips, demo checks) | Yes. |
| Check: record with the camera | Yes, after the browser asks for camera and mic. Needs HTTPS (the link is). |
| Check: choose a video | Yes. |
| The ML (CLAP sound + CLIP picture, same models and rules as the phone) | Yes, in the browser with ONNX Runtime Web. About 120 MB downloads on the first check, then it is cached. On a test clip the browser gave Likely upset 55% / Barking 81%, the phone 57% / 83%. |
| Pet photos, vet PDF import, vet PDF export | Yes (export downloads or opens the share sheet). |
| Voice log | Depends on the browser (Chrome yes, Safari partly, Firefox no). |

## What does not work in the browser

- Notifications and reminders that pop up: browsers don't get the phone's scheduled notifications.
- Saved clips after a reload: clips over 400 KB stay only for the visit. Logs and settings stay.
- "Sound only" saved clips: there is no ffmpeg in the browser, so Save keeps the video or nothing.
- Firebase sync between carers (same as the phone default: off).
- Speed: the check takes longer than on the iPhone, mostly on older phones (no GPU, one thread).

## Build and deploy (on the Mac)

```sh
cd app
tool/get_behaviour_model.sh      # same model files as the phone build
tool/build_web.sh                # flutter build web + models in parts + ONNX Runtime Web
cd web_host && npx wrangler deploy
```

Hosting is a Cloudflare Worker with static assets (free plan). Cloudflare limits
a file to 25 MiB, so the build stores each model in 20 MiB parts and
`web_host/worker.js` joins them back at `/models/<name>.onnx`.

## Files

- `lib/util/io.dart`, `paths.dart`, `media.dart`: `dart:io` / `path_provider` / file media on the phone, browser versions on the web.
- `lib/web/web_io.dart`: File and Directory kept in the browser.
- `lib/web/web_engine.dart`: the behaviour check in the browser.
- `web/mypet_media.js`: browser sound decoding and frame grabbing (ffmpeg's job on the phone).
- `web/index.html`, `web/flutter_bootstrap.js`: phone-width frame on laptops, loads ONNX Runtime Web.
- `tool/build_web.sh`, `web_host/`: build and Cloudflare hosting.
