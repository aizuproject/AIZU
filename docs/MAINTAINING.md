# Maintainer operations

## Initial commit and main protection

The repository starts empty. The first commit is prepared locally for review; neither the setup script nor the CI configuration pushes code.

1. Review the staged/committed source, license, documentation and media. Check `git status`, `git show --stat HEAD` and `python3 scripts/check-repository.py`.
2. After explicitly approving publication, perform the first push to `main`.
3. Immediately run `python3 scripts/configure-repository.py --apply` and verify the ruleset is **active** in GitHub Settings → Rules → Rulesets.
4. Confirm the initial Actions run succeeds. All later changes go through a PR.

The configuration script enables issue reporting, private vulnerability reporting, secret scanning, push protection and Dependabot security updates. It allows squash merges only and deletes merged branches. It does not grant extra access or create git refs.

The desired policy is versioned in [.github/rulesets/main.json](../.github/rulesets/main.json). When `main` does not exist, the script creates this ruleset in **disabled** mode to preserve the first-push exception. It activates the ruleset once `main` exists. Until that activation step, direct pushes are not blocked. This transition is explicit: repository files cannot enforce branch protection by themselves.

After activation, the ruleset has no bypass actors, including admins; it requires a PR, resolved review threads, an up-to-date branch, and the `Repository checks` and `iOS tests` checks from GitHub Actions. It blocks force pushes and deletion of `main` and allows only squash merges. Approval count is initially zero for a single-maintainer project. Increase it when the project has additional reviewers.

Use `python3 scripts/configure-repository.py` without `--apply` for a dry run. Changing GitHub settings requires administrator access through the authenticated GitHub CLI. The script targets `aizuproject/AIZU` unless `--repo` is explicitly supplied.

## Security and CI

Actions use commit-pinned dependencies, with weekly Dependabot updates. Public fork PRs receive no Discord credentials. Do not introduce `pull_request_target` to execute contributor code. Review workflow and dependency changes with the same care as application changes.

CodeQL covers the repository's Python tooling and Actions. Native application security review is still required; a green check is not a security certification. Swift analysis with third-party scanners should be added only after compatibility with the selected beta toolchain is verified.

The official [`xcode-27` runner](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md) is a preview environment and may change. Keep CI and the documented local toolchain in sync. Do not label an unexecuted workflow as passing.

## Releases

The public prerelease version in [VERSION](../VERSION) is `0.1.0-beta.1`; the iOS bundle uses numeric `0.1.0` and build `1`, with Beta shown in Settings. Earlier local version numbers do not belong to the public release series.

A future GitHub release should be marked **pre-release**. Tags, releases, binaries and publication are separate maintainer actions; the initial commit does not create them automatically. Before distributing binaries, review signing, included SDK terms and the personal-installation limits documented in the README.
