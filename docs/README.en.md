<p align="center"><img src="media/logo.png" width="88" alt="AIZU"></p>
<h1 align="center">AIZU</h1>
<p align="center">Share what you choose to do on iPhone and iPad with Discord.</p>
<p align="center"><strong>0.1.0 Beta</strong> · SwiftUI · iOS / iPadOS 17+ · MIT</p>
<p align="center"><a href="../README.md">한국어</a> · <strong>English</strong> · <a href="README.ja.md">日本語</a> · <a href="README.zh-CN.md">简体中文</a></p>

AIZU is an iPhone and iPad app for sharing apps and tasks through Discord Rich Presence. Add a game, an editing app, a video service, or a task of your own. You choose what to share and when to start or stop.

This is a **beta for building from source and installing on your own device**. It uses silent audio to keep the background connection alive while sharing and is not offered as an App Store release. It cannot keep running after you force-quit AIZU.

![AIZU activity screen on iPad](media/activity.png)

## Features

- **Apps and custom tasks:** find apps through App Store search or add an activity manually.
- **Activity details:** set the name, description, activity type, elapsed time and artwork. Device images stay local; Discord artwork requires a separate public HTTPS image URL.
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

*These are real iPad simulator screens with the interface set to Korean. The GIF cycles through idle, sharing and stopped states. The app is in preview mode, without an account or Discord traffic; this is not a recording of another Discord client's display.*

To open an app after sharing, configure an app URL or shortcut name in its activity settings. AIZU does not discover installed apps or their launch URLs. See the [development guide](DEVELOPMENT.md) for app-open and app-close automations.

| Custom activities | Language and connection settings |
| --- | --- |
| ![Custom activities](media/custom-activity.png) | ![Language and connection settings](media/settings.png) |

## Building

You need macOS, Xcode 27 beta with an iOS simulator runtime, and [XcodeGen](https://github.com/yonaskolb/XcodeGen). Device installation also requires Apple development signing. The deployment target is iOS/iPadOS 17.0; running on an iOS 17 device has not yet been verified.

```sh
git clone https://github.com/aizuproject/AIZU.git
cd AIZU
brew install xcodegen
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
AIZU_WITHOUT_SDK=1 zsh scripts/generate.sh
open iPadPresence.xcodeproj
```

Select the `iPadPresence` scheme and a simulator. The Xcode project is generated and is not committed. To explore the interface, add `--uitesting --ui-language en` to the Debug scheme's launch arguments. This mode uses in-memory sample data, does not load a saved account, and does not send activities to Discord.

For a real connection, supply your own Discord Application ID and install the official Social SDK, then regenerate the project. Follow the [connection setup](DEVELOPMENT.md). SDK binaries and credentials are not included in the repository.

## Background behavior and limitations

Silent audio starts with an activity and stops when sharing ends. Other music, calls, audio route changes or network conditions can interrupt it. It uses additional power; battery consumption has not been measured quantitatively.

| Situation | Current behavior |
| --- | --- |
| Switching apps, returning home or locking the screen | Attempts to maintain the connection while audio execution is allowed. |
| Guided Access | Has worked on some physical devices; continuous operation is not guaranteed across devices and apps. |
| Force-quitting AIZU | The connection cannot continue. |
| A missed app-close automation | The activity may remain shared. Stop it manually in AIZU. |

“Sent to Discord” means the SDK returned success, not that another person's client has been verified to display the activity. Activities use AIZU's Discord application; they do not become official integrations for the apps you select. AIZU is not an official Discord or Apple product.

Using silent audio to obtain background execution time is not a suitable App Store distribution strategy. See [Apple's review guideline 2.5.4](https://developer.apple.com/app-store/review/guidelines/#software-requirements).

## Privacy and security

AIZU sends the selected activity name, description, image URL and start time to Discord. App Store queries go to Apple, and remote images are fetched from their hosts. Login credentials are stored in the device's Keychain. AIZU has no collection server or analytics service of its own.

It does not read other apps' screens, documents or video titles, and does not request VPN, location or microphone access. Activities start through your selections or your Shortcuts automations. Report vulnerabilities [privately](https://github.com/aizuproject/AIZU/security/advisories/new), following the [security policy](../SECURITY.md).

## Contributing

File a [bug report](https://github.com/aizuproject/AIZU/issues/new/choose) with reproduction steps and your device, OS and AIZU versions. Submit changes through a pull request from a working branch. Read the [contributing guide](../CONTRIBUTING.md), [test coverage notes](TESTING.md) and [changelog](../CHANGELOG.md).

CI is configured to run repository checks and simulator tests without the Discord SDK or credentials. CodeQL checks Python tooling and GitHub Actions. These checks do not replace Swift security review or physical-device testing.

## License

AIZU source code is available under the [MIT license](../LICENSE). The Discord Social SDK is downloaded separately and remains subject to Discord's terms and licenses. See [third-party notices](../THIRD_PARTY_NOTICES.md).
