<p align="center"><img src="media/logo.png" width="88" alt="AIZU"></p>
<h1 align="center">AIZU</h1>
<p align="center">Share what you choose to do on iPhone and iPad with Discord.</p>
<p align="center"><strong>0.1.0 Beta</strong> · SwiftUI · iOS / iPadOS 17+ · MIT</p>
<p align="center"><a href="../README.md">한국어</a> · <strong>English</strong> · <a href="README.ja.md">日本語</a> · <a href="README.zh-CN.md">简体中文</a></p>

AIZU is a personal-install beta for sharing games, apps, and custom tasks through Discord Rich Presence.

![AIZU activity screen on iPad](media/activity.png)

## Features

- **Apps and custom tasks:** find apps through App Store search or add an activity manually.
- **Activity details:** set the name, description, activity type, elapsed time and artwork. Device images stay local; Discord artwork uses a public HTTPS image URL.
- **Share and launch:** open an app URL or a named shortcut after the activity update succeeds.
- **Shortcuts automation:** connect app-open and app-close events to starting and stopping a share.
- **One activity card:** preview the activity, check delivery status, retry or stop sharing.
- **Four languages:** Korean, English, Japanese and Simplified Chinese, selected from device preferences or changed in Settings.

## Using AIZU

1. Connect your Discord account in Settings.
2. Use **+** to add an app or task.
3. Enable **Activity sharing**, then select **Share** for an activity.
4. Select **Stop sharing** on the card when finished. Turning off sharing also ends the current activity.

![Starting and stopping a share](media/sharing.gif)

To open an app after sharing, configure an app URL or shortcut name in its activity settings. AIZU does not discover installed apps or their launch URLs. See the [development guide](DEVELOPMENT.md) for app-open and app-close automations.

| Custom activities | Language and connection settings |
| --- | --- |
| ![Custom activities](media/custom-activity.png) | ![Language and connection settings](media/settings.png) |

## Building

You need macOS, Xcode 27 beta with an iOS simulator runtime, and [XcodeGen](https://github.com/yonaskolb/XcodeGen). Device installation also requires Apple development signing.

```sh
git clone https://github.com/aizuproject/AIZU.git
cd AIZU
brew install xcodegen
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
AIZU_WITHOUT_SDK=1 zsh scripts/generate.sh
open iPadPresence.xcodeproj
```

Select the `iPadPresence` scheme and a simulator. For a real connection, supply your own Discord Application ID and install the official Social SDK, then regenerate the project. Follow the [connection setup](DEVELOPMENT.md).

## Background behavior and limitations

Silent audio starts with an activity and stops when sharing ends. Other audio apps, calls, and network changes can interrupt it. Force-quitting AIZU ends the connection.

## Privacy and security

AIZU sends the selected activity name, description, image URL and start time to Discord. App Store queries go to Apple and remote images are loaded from their hosts. Credentials are stored in the device Keychain; AIZU has no collection server or analytics service.

It does not read other apps' screens, documents or video titles, and does not request VPN, location or microphone access. Activities start through your selections or your Shortcuts automations. Report vulnerabilities [privately](https://github.com/aizuproject/AIZU/security/advisories/new), following the [security policy](../SECURITY.md). If GHSA is unavailable or you have another security-related inquiry, email [me@st4rain.com](mailto:me@st4rain.com).

## Contributing

File a [bug report](https://github.com/aizuproject/AIZU/issues/new/choose) with reproduction steps and your device, OS and AIZU versions. Submit changes through a pull request from a working branch. Read the [contributing guide](../CONTRIBUTING.md), [test coverage notes](TESTING.md) and [changelog](../CHANGELOG.md).

## License

AIZU source code is available under the [MIT license](../LICENSE). The Discord Social SDK is downloaded separately and remains subject to Discord's terms and licenses. See [third-party notices](../THIRD_PARTY_NOTICES.md).
