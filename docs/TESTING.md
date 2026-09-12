# Testing and documentation media

## Automated tests

Select Xcode 27, then run:

```sh
AIZU_WITHOUT_SDK=1 zsh scripts/test.sh \
  -only-testing:iPadPresenceTests \
  -only-testing:iPadPresenceUITests/PresenceUITests \
  -only-testing:iPadPresenceUITests/LanguageUITests
```

The script selects an available iPhone simulator. Set `PRESENCE_SIMULATOR_ID` to test a specific iPhone or iPad. `PRESENCE_BUILD_DIR` overrides the DerivedData path. Test bundles are saved under ignored `artifacts/`.

Coverage includes state persistence, OAuth callback validation and PKCE, Keychain operations using unique test accounts, artwork and launch URL validation, cancellation, audio lifetime integration, sharing controls, custom activities, app launch settings and four-language selection. These tests use preview or fake transports and do not require a Discord account.

`RealDeviceCheck` is opt-in because it operates on a real account and device. Do not enable it in public CI. It is intended for a developer who has explicitly prepared a test device and activity.

## Validation scope

The UI and state flow have been tested on iPhone 17 Pro / iOS 27 and iPad Pro M4 / iPadOS 26 simulators. The initial source-release build is also checked with the Discord SDK excluded. Full test counts and failures, if any, are available in the local `.xcresult` or GitHub Actions output after the workflows run.

Previous physical-device testing observed activity remaining visible during screen lock and a short Guided Access session. That observation is not a guarantee of continuous operation. Still requiring device validation:

- iOS/iPadOS 17 execution, beyond the configured deployment target;
- long sessions, battery use and thermal behavior;
- other audio apps, calls, Bluetooth changes and network transitions;
- complete Shortcuts open/close flows under different system states;
- OAuth expiry and revoked access in a live account.

Repository checks validate release metadata, public file boundaries, local Markdown links, localization completeness and placeholder consistency. They include a limited credential-pattern check; GitHub secret scanning is a separate control. CodeQL scans Python and Actions, not Swift or Objective-C++.

## Initial beta validation — 2026-09-12

A separate copy of the staged public source, without local configuration or SDK binaries, passed 45 unit/integration tests and 7 UI tests on the iPhone 17 Pro / iOS 27 simulator. The iPad Pro M4 / iPadOS 26 documentation capture passed separately. Three archive-installer tests and local workflow syntax checks also passed. A signed Release build of 0.1.0 Beta with the locally installed SDK completed successfully; it was not installed on a device as part of this release preparation.

GitHub Actions and CodeQL have not run for this source release yet: publication is pending maintainer review. A local successful build does not establish a successful hosted CI run.

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
