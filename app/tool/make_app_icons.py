"""Makes every app icon size from test/screens/out/app_icon_1024.png (drawn by
test/screens/app_icon_test.dart). iOS icons have no transparency."""
import json
import pathlib
import sys

from PIL import Image

app = pathlib.Path(__file__).resolve().parent.parent
src = Image.open(app / 'test/screens/out/app_icon_1024.png').convert('RGB')

ios = app / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for img in json.loads((ios / 'Contents.json').read_text())['images']:
    side = round(float(img['size'].split('x')[0]) * int(img['scale'][0]))
    src.resize((side, side), Image.LANCZOS).save(ios / img['filename'])

android = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
for name, side in android.items():
    d = app / f'android/app/src/main/res/mipmap-{name}'
    if d.exists():
        src.resize((side, side), Image.LANCZOS).save(d / 'ic_launcher.png')

web = app / 'web'
if web.exists():
    (web / 'icons').mkdir(exist_ok=True)
    for n in (192, 512):
        src.resize((n, n), Image.LANCZOS).save(web / f'icons/Icon-{n}.png')
        src.resize((n, n), Image.LANCZOS).save(web / f'icons/Icon-maskable-{n}.png')
    src.resize((32, 32), Image.LANCZOS).save(web / 'favicon.png')
print('icons written', file=sys.stderr)
