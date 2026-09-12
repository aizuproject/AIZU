# Testing and documentation media

## Automated tests

Select Xcode 27, then run:

```sh
AIZU_WITHOUT_SDK=1 zsh scripts/test.sh \
  -only-testing:iPadPresenceTests \
  -only-testing:iPadPresenceUITests/PresenceUITests \
  -only-testing:iPadPresenceUITests/LanguageUITests
```

The script selects an available iPhone simulator. Set `PRESENCE_SIMULATOR_ID` for a specific device and `PRESENCE_BUILD_DIR` for a custom DerivedData path. Results are written to ignored `artifacts/`.

Tests cover stored activities, OAuth callbacks, Keychain access, artwork and launch URL validation, sharing controls, audio lifetime, and language selection. They use preview transports and do not need a Discord account. `RealDeviceCheck` is opt-in and must not run in public CI.

Repository checks validate public files, links, localization completeness, and release metadata. CodeQL scans Python tooling and GitHub Actions.

## Recreate README media

The README uses actual iPad simulator screens. The GIF is a sequence of three captured states, not a fabricated Discord client or a claim about live delivery.

```sh
AIZU_WITHOUT_SDK=1 zsh scripts/generate.sh
TEST_RUNNER_AIZU_CAPTURE_README=1 xcodebuild \
  -project iPadPresence.xcodeproj -scheme iPadPresence \
  -destination 'platform=iOS Simulator,id=YOUR_IPAD_SIMULATOR_ID' \
  -resultBundlePath artifacts/readme.xcresult \
  -only-testing:iPadPresenceUITests/ReadmeCaptureTests test
xcrun xcresulttool export attachments \
  --path artifacts/readme.xcresult --output-path artifacts/readme-frames
python3 scripts/build-readme-media.py artifacts/readme-frames
```

Requires `ffmpeg` (`brew install ffmpeg`). Choose a fresh result-bundle path for each run. The capture test uses Korean UI, in-memory sample data and no saved account. It takes screenshots through `XCUIScreen` so the full iPad landscape display is preserved. Remove account details from any additional screenshots contributed manually.
