# Security Policy

## Reporting a vulnerability

Please do not report security issues in public issues or pull requests.

- **Preferred:** use [GitHub Security Advisories](https://github.com/aizuproject/AIZU/security/advisories/new) to report a vulnerability privately.
- **Alternative:** if GHSA is unavailable, email [me@st4rain.com](mailto:me@st4rain.com) with `[AIZU Security]` in the subject.

Include the affected version or commit, device and OS, clear reproduction steps, the expected and actual behavior, and the likely impact. Redact tokens, authorization codes, full callback URLs, and personal data. Use a test account you control.

## Scope

Security reports include credential exposure or misuse in OAuth, account linking, or Keychain handling; activity sharing that bypasses the user's choices; unsafe handling of images, URLs, stored data, SDK archives, or repository workflows.

UI issues, ordinary connection failures, battery use, and feature requests belong in [regular issues](https://github.com/aizuproject/AIZU/issues/new/choose). If unsure, report privately first.

## Supported versions

Security fixes target the latest 0.1.x beta revision. Earlier local development builds are not maintained separately.

## Disclosure

We review reports privately, confirm impact, prepare a fix, and coordinate disclosure with the reporter. A GitHub Security Advisory may be published once a fix is available. Please keep details private until then.

This is a best-effort project. It does not guarantee response times, CVE assignment, or a bug bounty.
