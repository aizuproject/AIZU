# Development and setup

This guide uses the Xcode scheme and bundle names retained from the original project. The user-facing application is AIZU.

## Requirements

- macOS and Xcode 27 beta, with an installed iOS simulator runtime.
- XcodeGen (`brew install xcodegen`).
- Python 3 for repository and SDK tools. Python 3.11+ is recommended.
- An Apple development team and a unique bundle identifier for installing a signed build on your own device.

Use `xcode-select` or export `DEVELOPER_DIR` to select Xcode 27. The public CI uses GitHub's [`xcode-27` runner](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md). The deployment target is 17.0, distinct from the SDK used to compile the app.

## Preview without the Discord SDK

```sh
AIZU_WITHOUT_SDK=1 zsh scripts/generate.sh
open iPadPresence.xcodeproj
```

In **Product → Scheme → Edit Scheme → Run → Arguments**, add `--uitesting --ui-language en`. Use `ko`, `ja` or `zh-Hans` for the other languages. Run the Debug configuration on a simulator.

The fixture uses in-memory activities, does not load saved credentials, and uses preview transport with no silent-audio playback. It does not preserve edits after relaunch. Remove those arguments to use normal storage and a real connection. These fixture arguments are unavailable in Release builds.

## Connect your own Discord application

1. Create an application in the [Discord Developer Portal](https://discord.com/developers/applications).
2. Enable **Public Client** in OAuth2 settings. Add `discord-YOUR_APPLICATION_ID:/authorize/callback` as a redirect, substituting your numeric application ID.
3. Complete Social SDK registration under Discord's current requirements. Download the official C++ SDK. Tested archive: `DiscordSocialSdk-1.10.19337.zip`.
4. Install the iOS framework locally:

   ```sh
   python3 scripts/install-sdk.py "$HOME/Downloads/DiscordSocialSdk-1.10.19337.zip"
   cp Config/Local.example.xcconfig Config/Local.xcconfig
   ```

5. Set `DISCORD_APPLICATION_ID` in `Config/Local.xcconfig` to your application's ID. Set `DEVELOPMENT_TEAM` for device signing. Do not add a client secret or user token. For independent device signing, also override `PRODUCT_BUNDLE_IDENTIFIER` with your own identifier.
6. Run `zsh scripts/generate.sh` again, without `AIZU_WITHOUT_SDK=1`. The generator links the SDK when it exists in `Vendor/discord_partner_sdk.xcframework`.
7. Build and run, remove preview launch arguments, and connect the account from AIZU Settings.

`Config/Local.xcconfig`, SDK binaries, provenance and supplied SDK notices are ignored by Git. The public configuration uses application ID `0`. The application ID is not a secret, but each contributor should use their own Discord application. SDK installation does not grant any additional Discord permissions; account linking and presence sharing remain subject to Discord's settings and terms.

## Configure app launch and automation

For launch after sharing, edit an activity and choose an app URL or shortcut name. A URL must be an application scheme or HTTPS URL; unsafe schemes and credentials in URLs are rejected. An HTTPS URL may open a website. To launch an app through Shortcuts, create a shortcut with **Open App**, then enter its exact name in AIZU. Do not add an AIZU start action to that same shortcut, which could create a loop.

For automatic activity changes, create two personal automations in Shortcuts:

- **App → Is Opened → Run Immediately → AIZU Start app activity → the matching activity.**
- **App → Is Closed → Run Immediately → AIZU Stop app activity → the same activity.**

Enable sharing in AIZU first. App-close events include switching to another app. If an automation is not delivered, AIZU cannot infer it from the other app's process; stop sharing manually. A system refusal to start background audio is surfaced as an error.

## Layout

```text
iPadPresence/
  App/           Application entry point and presence controller
  Domain/        Activities, sessions and stored state
  Services/      OAuth, transport, audio lifetime, search and localization
  Integration/   Discord C++ bridge and App Intents
  Views/         SwiftUI screens
  Resources/     Assets, localized strings and Info.plist
iPadPresenceTests/       Unit and integration tests
iPadPresenceUITests/     UI tests and opt-in documentation capture
scripts/                 Project generation, testing and repository tools
```

The generated project is intentionally excluded. Regenerate it whenever `project.yml` or SDK availability changes. See [testing](TESTING.md) for the validation scope and [maintaining](MAINTAINING.md) for repository administration.
