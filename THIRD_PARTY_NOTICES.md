# Third-party components

## Discord Social SDK

AIZU optionally links the official Discord Social SDK through an Objective-C++ bridge. The SDK is not part of AIZU's MIT-licensed source and is not redistributed in this repository. Obtain it from the [Discord Developer Portal](https://discord.com/developers/applications) under Discord's applicable terms. Integration documentation is available from [Discord](https://docs.discord.com/developers/discord-social-sdk/overview).

The tested C++ archive is `DiscordSocialSdk-1.10.19337.zip`, SHA-256:

```text
d784097504685953849cc2842561d8a8013326fe0b8df65a1de63ddefde62045
```

The installer extracts the release iOS XCFramework and its supplied notices into the ignored `Vendor` directory. Preserve those notices when distributing any build containing the SDK, and verify that your intended distribution complies with the SDK terms. AIZU does not use the SDK's voice features or bundle Krisp separately.

## Apple frameworks and symbols

SwiftUI, App Intents, AVFoundation and other Apple system frameworks are platform dependencies, not redistributed source dependencies. SF Symbols are used through Apple's system APIs and remain subject to Apple's terms.

## App names and artwork

Third-party app names in examples identify the corresponding apps; their owners do not sponsor or endorse AIZU. App Store artwork and user-supplied images are not relicensed by this project. The documentation screenshots use letter placeholders rather than third-party app artwork.
