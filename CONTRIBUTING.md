# Contributing to AIZU

버그 수정, 번역 개선, 접근성, 문서와 테스트 기여를 환영합니다. 논의와 PR은 한국어 또는 영어로 작성해 주세요. 큰 기능 변경은 구현 전에 이슈에서 사용 사례와 범위를 먼저 논의하면 좋습니다.

Contributions to fixes, translations, accessibility, documentation and tests are welcome. Korean and English are both accepted in issues and pull requests. For substantial changes, open an issue first so the scope and user need can be discussed.

## Local development

1. Follow [the development guide](docs/DEVELOPMENT.md). A Discord account and SDK are unnecessary for preview work and normal automated tests.
2. Create a branch from `main`, such as `fix/activity-retry` or `docs/setup`.
3. Keep each PR focused on one problem. Describe the resulting behavior and relevant limits.
4. Run `python3 scripts/check-repository.py` and `AIZU_WITHOUT_SDK=1 zsh scripts/test.sh` with Xcode 27 selected.
5. Include screenshots for UI changes and reproduction steps for fixes.

## Review and merge

After repository initialization, changes to `main` go through pull requests, including maintainer changes. The configured rules require `Repository checks` and `iOS tests`, an up-to-date branch, resolved review threads, and squash merging. Force pushes and deletion of `main` are blocked. There are no configured bypass actors.

There is currently one maintainer. Reviews are welcome but a second person's approval is not mandatory, so the maintainer can merge their own PR after checks pass. CODEOWNERS routes reviews to the maintainer. This can be tightened when more maintainers join. Initial repository setup is documented in [maintainer operations](docs/MAINTAINING.md).

## Code and translations

- Preserve stored activity IDs and existing Shortcuts intent/entity identifiers.
- Keep credentials in Keychain. Never log OAuth tokens, authorization codes or complete callback URLs.
- Keep changes to connection lifecycle, cancellation and audio interruption behavior covered by relevant tests.
- UI strings belong in all four `Localizable.strings` files. Preserve formatting arguments and user-entered content.
- Keep the Korean, English, Japanese and Simplified Chinese READMEs consistent when behavior or setup changes. Do not claim a device or OS is tested without evidence.
- Do not commit `Config/Local.xcconfig`, generated Xcode projects, build results, provisioning profiles, device identifiers or Discord SDK binaries.

## Community expectations

Read the [community code of conduct](CODE_OF_CONDUCT.md).

Be specific, patient and respectful. Critique ideas and code without personal attacks. Harassment, discrimination, threats and publishing someone else's private information are not acceptable. Maintainers may edit or remove abusive content and restrict participation where needed.

## Licensing and security

By submitting a contribution, you agree to license it under this project's [MIT license](LICENSE). Only contribute material you have the right to share. Security issues belong in the [private reporting channel](https://github.com/aizuproject/AIZU/security/advisories/new), not a public issue or PR; see [SECURITY.md](SECURITY.md).
