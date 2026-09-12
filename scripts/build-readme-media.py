#!/usr/bin/env python3
"""Build README PNGs and a state-by-state GIF from exported XCTest screenshots."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('frames', type=Path, help='xcresulttool attachment export directory')
args = parser.parse_args()
if not shutil.which('ffmpeg'):
    parser.error('ffmpeg is required (brew install ffmpeg)')
root = Path(__file__).resolve().parent.parent
out = root / 'docs/media'
out.mkdir(parents=True, exist_ok=True)
manifest = json.loads((args.frames / 'manifest.json').read_text())
frames = {}
for test in manifest:
    for item in test['attachments']:
        name = item['suggestedHumanReadableName'].split('_0_')[0]
        if name in {'01-idle', '02-sharing', '03-stopped', '04-library', '05-custom-activity', '06-settings'}:
            source = (args.frames / item['exportedFileName']).resolve()
            if not source.is_relative_to(args.frames.resolve()):
                raise SystemExit('Attachment path is outside the export directory')
            frames[name] = source
required = ['01-idle', '02-sharing', '03-stopped', '04-library', '05-custom-activity', '06-settings']
if any(name not in frames for name in required):
    raise SystemExit('Missing capture frames. Run ReadmeCaptureTests with TEST_RUNNER_AIZU_CAPTURE_README=1.')

def ffmpeg(*args):
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', *map(str, args)], check=True)

for source, target in [('02-sharing', 'activity.png'), ('04-library', 'library.png'), ('05-custom-activity', 'custom-activity.png'), ('06-settings', 'settings.png')]:
    ffmpeg('-i', frames[source], '-vf', 'scale=1440:-2:flags=lanczos', '-frames:v', '1', out / target)
with tempfile.TemporaryDirectory() as directory:
    temp = Path(directory)
    for i, name in enumerate(required[:3]):
        shutil.copyfile(frames[name], temp / f'{i:02}.png')
    ffmpeg('-framerate', '1/3', '-i', temp / '%02d.png', '-filter_complex',
           '[0:v]scale=960:-2:flags=lanczos,split[a][b];[a]palettegen=stats_mode=full[p];[b][p]paletteuse=dither=bayer:bayer_scale=4',
           '-loop', '0', out / 'sharing.gif')
print('Created README media in docs/media')
