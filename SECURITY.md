# 보안 정책 / Security Policy

AIZU는 Discord 계정 인증 정보와 사용자가 선택한 활동을 처리합니다. 인증 정보 노출, 동의하지 않은 활동 전송, 외부 입력 처리 과정에서 발생하는 보안 문제를 우선적으로 검토합니다. 이 문서는 제보 방법과 검토 범위를 설명합니다.

[한국어](#취약점-제보) · [English](#reporting-a-vulnerability)

## 취약점 제보

보안 취약점은 공개 이슈나 PR 대신 아래의 비공개 경로로 알려 주세요.

1. **권장: GitHub Security Advisories(GHSA)** — [Report a vulnerability](https://github.com/aizuproject/AIZU/security/advisories/new)를 통해 비공개로 제보해 주세요. 재현 정보, 영향 범위와 수정 방안을 같은 공간에서 논의할 수 있습니다.
2. **대체 연락처: [me@st4rain.com](mailto:me@st4rain.com)** — GHSA를 이용할 수 없거나 그 밖의 보안 관련 문의가 있다면 이메일로 보내 주세요. 제목에 `[AIZU Security]`를 포함해 주시면 분류에 도움이 됩니다.

어느 경로로 제보하든 실제 OAuth 토큰, 인증 코드, 전체 콜백 URL, 타인의 개인정보는 보내지 마세요. 필요한 경우 민감한 정보를 제거한 테스트 계정과 최소 재현 자료를 사용해 주세요.

### 제보에 포함할 내용

- 영향받는 AIZU 버전 또는 커밋, 기기와 OS 버전. 빌드 설정이나 SDK 버전이 관련 있다면 함께 적어 주세요.
- 발생 조건과 재현 단계. 가능한 경우 최소 재현 코드나 개인정보를 제거한 입력 파일을 첨부해 주세요.
- 예상한 동작과 실제 동작, 공격자가 얻을 수 있는 권한이나 노출되는 정보 등 예상 영향.
- 민감한 정보를 제거한 로그, 오류 추적 또는 화면 자료.

서로 다른 문제는 가급적 별도로 제보해 주세요. 자동화 도구나 AI로 발견한 문제도 같은 경로로 받습니다. 도구의 결과만 전달하기보다 직접 확인한 내용과 아직 확인하지 못한 부분을 구분해 주세요. 재현이 어렵다면 확인한 조건과 근거를 설명해 주세요.

## 검토 범위

다음과 같은 문제를 보안 제보로 검토합니다.

- OAuth 응답 검증, 계정 연결 또는 Keychain 처리 과정의 인증 정보 노출·오용.
- 사용자의 공유 설정이나 종료 요청을 우회하여 활동 정보를 전송하는 문제.
- 이미지, URL, 저장 데이터 또는 SDK 설치 파일 처리에서 발생하는 정보 노출, 임의 파일 쓰기나 의도하지 않은 실행.
- 저장소의 빌드·배포 도구 또는 GitHub Actions를 통한 자격 증명 노출과 신뢰 경계 우회.

보안 영향이 없는 화면 오류, 일반적인 연결 끊김, 배터리 사용량과 기능 제안은 [일반 이슈](https://github.com/aizuproject/AIZU/issues/new/choose)로 접수해 주세요. 보안 문제인지 판단하기 어렵다면 먼저 비공개로 문의해도 됩니다. Discord SDK나 Apple 프레임워크 자체의 문제로 확인되면 해당 공급자에게도 제보가 필요할 수 있습니다.

## 지원 버전

| 버전 | 보안 수정 |
| --- | --- |
| 최신 0.1.x 베타 | 최신 리비전을 대상으로 검토·수정 |
| 이전 로컬 개발 빌드 | 별도 유지관리하지 않음 |

베타 버전은 독립적인 보안 감사를 받지 않았습니다. 자동 검사 통과가 보안상의 안전을 보증하지는 않습니다.

## 검토와 공개 절차

제보를 받은 뒤 재현 가능성과 영향을 확인하고, 필요한 추가 정보를 비공개로 요청합니다. 확인된 문제는 영향과 심각도를 기준으로 수정 우선순위를 정합니다. 수정과 검증을 마치면 제보자와 공개 시점을 협의하고, 필요한 경우 GitHub Security Advisory로 영향받는 버전과 해결 방법을 안내합니다. 제보자 표기는 당사자의 동의를 따릅니다.

공개 전까지 취약점의 세부 내용은 비공개로 유지해 주세요. 대응은 가능한 범위에서 이루어지며, 고정된 응답·수정 기한, CVE 발급 또는 보상금은 보장하지 않습니다.

## 데이터 처리와 점검 범위

로그인은 시스템 인증 세션과 PKCE를 사용하며 인증 정보는 기기의 Keychain에 저장합니다. 선택한 활동 정보는 Discord로, App Store 검색어는 Apple로 전달됩니다. 원격 이미지를 표시할 때는 해당 이미지 호스트에 연결합니다. 기기 이미지를 AIZU가 업로드하지는 않습니다.

다른 앱의 화면·문서를 읽거나 마이크·위치·VPN 권한을 사용하지 않습니다. AIZU 자체의 수집 서버나 분석 서비스는 없습니다. 무음 오디오는 연결 유지에 사용하며, 백그라운드 동작의 제약은 [README](README.md)에 설명되어 있습니다.

GitHub에는 시크릿 스캔·푸시 보호, 비공개 취약점 제보와 Dependabot 보안 업데이트가 설정되어 있습니다. CI 구성은 Discord 자격 증명을 사용하지 않으며, 워크플로 액션은 커밋 SHA로 고정합니다. CodeQL의 대상은 Python 도구와 GitHub Actions입니다. Swift·Objective-C++ 코드와 별도로 내려받는 Discord SDK는 추가 검토가 필요합니다.

---

## Reporting a vulnerability

AIZU handles Discord authentication credentials and activity information chosen by the user. Please report security issues privately rather than opening a public issue or pull request.

1. **Preferred: GitHub Security Advisories (GHSA).** Use [Report a vulnerability](https://github.com/aizuproject/AIZU/security/advisories/new) to share reproduction details and discuss the impact and a possible fix privately.
2. **Alternative: [me@st4rain.com](mailto:me@st4rain.com).** If you cannot use GHSA, or have another security-related inquiry, contact this address. Include `[AIZU Security]` in the subject line.

Do not send live OAuth tokens, authorization codes, complete callback URLs or another person's private data through either channel. Use a test account you control and remove sensitive information from supporting material.

### What to include

- The affected AIZU version or commit, device and OS. Include build settings and the SDK version when relevant.
- The conditions and steps needed to reproduce the issue, with a minimal example or sanitized input file where possible.
- Expected and actual behavior, and the potential impact: for example, information exposed or capabilities gained by an attacker.
- Redacted logs, error traces or screenshots that help explain the finding.

Please keep unrelated findings in separate reports. Findings discovered with automated or AI tools are welcome. Explain what you have verified and what remains uncertain instead of forwarding raw tool output alone. If reproduction is difficult, describe the conditions and evidence you have established.

## Scope

We review security reports involving credential exposure or misuse in OAuth, account linking or Keychain handling; activity transmission that bypasses the user's sharing choices or stop request; unsafe image, URL, stored-data or SDK archive processing; and credential exposure or trust-boundary failures in repository tooling and workflows.

UI problems, ordinary connection interruptions, battery use and feature requests without a security impact belong in [regular issues](https://github.com/aizuproject/AIZU/issues/new/choose). If you are unsure whether a finding is security-related, ask privately first. Issues confirmed to originate in the Discord SDK or Apple frameworks may also need to be reported to the relevant vendor.

## Supported versions and disclosure

Security fixes target the latest revision of the 0.1.x beta series. Earlier local development builds are not maintained separately. The beta has not undergone an independent security audit, and automated checks do not certify its security.

Reports are reviewed for reproducibility and impact. We may request more information privately and prioritize confirmed issues by severity. After a fix has been validated, we coordinate disclosure with the reporter and, where appropriate, publish a GitHub Security Advisory describing affected versions and remediation. Reporter credit is subject to consent.

Please keep vulnerability details private until disclosure has been coordinated. Handling is best effort: there is no guaranteed response or fix deadline, CVE assignment, or bug bounty.

## Data boundaries and repository controls

Authentication uses the system authentication session and PKCE; credentials are stored in the device's Keychain. Selected activities go to Discord, App Store queries go to Apple, and remote artwork contacts its image host. AIZU does not upload local artwork, inspect other apps' screens or documents, or request microphone, location or VPN access. It has no first-party collection server or analytics service. Silent-audio connection behavior is documented in the [README](docs/README.en.md).

GitHub secret scanning, push protection, private vulnerability reporting and Dependabot security updates are configured. CI is configured without Discord credentials, and workflow actions are pinned to commit SHAs. CodeQL covers Python tooling and GitHub Actions. Swift, Objective-C++ and the separately downloaded Discord SDK require additional review.
