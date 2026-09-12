#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
# Uses the selected Xcode; export DEVELOPER_DIR to choose a different installation.
export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
presence_simulator="${PRESENCE_SIMULATOR_ID:-}"
if [[ -z "$presence_simulator" ]]; then
  presence_simulator=$(xcrun simctl list devices available --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next((x["udid"] for r,ds in d["devices"].items() if "iOS" in r for x in ds if "iPhone" in x["name"]), ""))')
fi
if [[ -z "$presence_simulator" ]]; then
  print -u2 "Install an iOS simulator runtime in Xcode, or set PRESENCE_SIMULATOR_ID."
  exit 1
fi
presence_build="${PRESENCE_BUILD_DIR:-$HOME/Library/Developer/Xcode/DerivedData/AIZU}"
presence_result="artifacts/Tests-$(date +%Y%m%d-%H%M%S).xcresult"
mkdir -p artifacts
zsh scripts/generate.sh
xcodebuild -project iPadPresence.xcodeproj -scheme iPadPresence \
  -destination "platform=iOS Simulator,id=$presence_simulator" \
  -derivedDataPath "$presence_build" -resultBundlePath "$presence_result" \
  ONLY_ACTIVE_ARCH=YES test "$@"
