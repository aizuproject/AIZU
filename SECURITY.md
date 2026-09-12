# Security policy / 보안 정책

## Reporting a vulnerability

Use **Security → Report a vulnerability**, or [open a private report](https://github.com/aizuproject/AIZU/security/advisories/new). Please do not disclose an unpatched vulnerability, OAuth token, authorization code or full callback URL in a public issue, PR, screenshot or log.

Include the affected version or commit, device and OS, impact, and minimal reproduction steps. Use a test account you control. Redact credentials and personal data. Reports are reviewed on a best-effort basis; the project does not offer a guaranteed response time or bug bounty.

보안 취약점은 위의 비공개 제보 기능을 이용해 주세요. 영향받는 버전·커밋, 기기·OS, 영향과 재현 방법을 알려 주세요. 공개 이슈에 인증 정보나 아직 수정되지 않은 취약점의 세부 내용을 올리지 마세요. 제보는 가능한 범위에서 검토하며 응답 기한이나 보상금을 보장하지 않습니다.

## Supported versions

| Version | Security fixes |
| --- | --- |
| Latest 0.1.x beta | Best effort; update to the latest revision |
| Earlier local development builds | Not maintained |

A beta has not undergone an independent security audit. Automated checks do not certify that the application is secure.

## Data boundaries

- OAuth uses the system authentication session and PKCE. Credentials are stored in the device's Keychain, not in repository configuration.
- Selected activity fields are sent to Discord. Search queries go to Apple; remote artwork contacts its image host. User-selected app URLs and shortcuts may open other apps.
- Local images are not uploaded by AIZU. A public image URL is required for Discord artwork.
- The application does not inspect other apps' screens, capture microphone audio, provide a VPN or read location data. Silent audio is used for connection lifetime only.
- AIZU has no first-party analytics or collection backend. Apple, Discord and user-selected image hosts operate under their own policies.

## Repository controls

Secret scanning, push protection, private vulnerability reporting and Dependabot security updates are configured on GitHub. Workflow actions are pinned to commit SHAs. CI uses read-only repository permissions and no Discord credentials. CodeQL covers Python tooling and GitHub Actions; Swift and Objective-C++ require separate review and simulator/device testing.

The Discord SDK is downloaded separately. Its licenses, provenance and update policy must be reviewed independently. Never include the SDK or a signed build containing private credentials in a vulnerability report.
