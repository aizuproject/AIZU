<p align="center"><img src="docs/media/logo.png" width="88" alt="AIZU"></p>
<h1 align="center">AIZU</h1>
<p align="center">iPhone과 iPad에서, 내가 선택한 활동을 Discord에.</p>
<p align="center"><strong>0.1.0 Beta</strong> · SwiftUI · iOS / iPadOS 17+ · MIT</p>
<p align="center"><strong>한국어</strong> · <a href="docs/README.en.md">English</a> · <a href="docs/README.ja.md">日本語</a> · <a href="docs/README.zh-CN.md">简体中文</a></p>

AIZU는 게임, 앱, 직접 만든 작업을 Discord Rich Presence로 공유하는 개인 설치용 베타입니다.

![iPad의 AIZU 활동 화면](docs/media/activity.png)

## 주요 기능

- **앱과 작업 등록** — App Store 검색 또는 직접 입력으로 활동 목록을 구성합니다.
- **표시 정보 설정** — 이름, 설명, 활동 유형, 경과 시간과 이미지를 지정합니다. 기기 이미지는 로컬에 저장하고, Discord에는 공개 HTTPS 이미지 URL을 사용합니다.
- **공유와 앱 실행** — 활동 전송 후 앱 URL이나 사용자가 지정한 단축어를 실행합니다.
- **단축어 자동화** — 대상 앱을 열고 닫을 때 공유를 시작·종료하도록 연결할 수 있습니다.
- **공유 상태 확인** — 미리보기 카드에서 전송 상태를 확인하고, 공유 종료나 재시도를 실행합니다.
- **네 언어 지원** — 한국어·영어·일본어·중국어 간체를 지원합니다. 기기의 선호 언어를 따르며 설정에서 변경할 수 있습니다.

## 사용 흐름

1. 설정에서 Discord 계정을 연결합니다.
2. **+** 버튼으로 앱이나 작업을 등록합니다.
3. **활동 공유**를 켜고 원하는 항목의 **공유**를 누릅니다.
4. 작업을 마치면 카드의 **공유 종료**를 누릅니다. 전체 공유를 꺼도 현재 활동이 종료됩니다.

![공유 시작과 종료 흐름](docs/media/sharing.gif)

앱을 함께 열려면 **앱 → 활동 설정 → 앱 실행**에서 URL 또는 단축어 이름을 지정하세요. 앱 설치 여부나 실행 URL은 자동으로 감지하지 않습니다. 앱 열림·닫힘 자동화 구성은 [개발 및 사용 안내](docs/DEVELOPMENT.md)를 참고하세요.

| 직접 등록 | 언어 및 연결 설정 |
| --- | --- |
| ![직접 등록](docs/media/custom-activity.png) | ![언어 및 연결 설정](docs/media/settings.png) |

## 빌드하기

**필요 환경:** macOS, Xcode 27 베타와 iOS 시뮬레이터 런타임, [XcodeGen](https://github.com/yonaskolb/XcodeGen). 실기기 설치에는 Apple 개발 서명 설정이 필요합니다.

```sh
git clone https://github.com/aizuproject/AIZU.git
cd AIZU
brew install xcodegen
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
AIZU_WITHOUT_SDK=1 zsh scripts/generate.sh
open AIZU.xcodeproj
```

`AIZU` 스킴과 시뮬레이터를 선택하세요. 실제 Discord 연결에는 본인의 Discord Application ID와 공식 Social SDK가 필요합니다. [연결 설정](docs/DEVELOPMENT.md)을 완료하고 프로젝트를 다시 생성하세요.

## 백그라운드 동작과 현재 한계

공유 중에는 무음 오디오로 백그라운드 연결을 유지합니다. 다른 오디오 앱, 통화, 네트워크 상태에 따라 중단될 수 있고 AIZU를 강제 종료하면 연결도 종료됩니다.

## 개인정보와 보안

선택한 활동의 이름·설명·이미지 URL·시작 시각을 Discord에 전송합니다. App Store 검색어는 Apple에 전달되며 원격 이미지는 해당 호스트에서 불러옵니다. 로그인 정보는 기기의 Keychain에 저장하며 AIZU는 자체 수집 서버나 분석 도구를 사용하지 않습니다.

다른 앱의 화면·문서·영상 제목을 읽지 않으며 VPN, 위치, 마이크 권한을 사용하지 않습니다. 활동은 직접 선택하거나 사용자가 만든 단축어로 시작합니다. 보안 취약점은 공개 이슈 대신 [비공개로 제보](https://github.com/aizuproject/AIZU/security/advisories/new)해 주세요. GHSA를 이용하기 어렵거나 그 밖의 보안 문의가 있다면 [me@st4rain.com](mailto:me@st4rain.com)으로 연락해 주세요. 자세한 범위는 [보안 정책](SECURITY.md)에 있습니다.

## 개발에 참여하기

버그는 재현 단계와 기기·OS·AIZU 버전을 포함해 [이슈](https://github.com/aizuproject/AIZU/issues/new/choose)로 남겨 주세요. 변경 사항은 작업 브랜치에서 PR로 제출합니다. [기여 안내](CONTRIBUTING.md), [검증 범위](docs/TESTING.md), [변경 이력](CHANGELOG.md)을 참고하세요.

## 라이선스

AIZU 소스는 [MIT 라이선스](LICENSE)로 제공합니다. Discord Social SDK에는 Discord의 별도 약관과 라이선스가 적용되며 직접 내려받아야 합니다. [외부 구성요소 안내](THIRD_PARTY_NOTICES.md)를 확인하세요.
