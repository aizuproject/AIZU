# Maintainer notes

`main` accepts squash merges through pull requests only. Required checks are `Repository checks` and `iOS tests`; force pushes and branch deletion are blocked. The policy lives in [.github/rulesets/main.json](../.github/rulesets/main.json).

Repository settings enable private vulnerability reports, secret scanning, push protection, Dependabot security updates, and automatic deletion of merged branches. Use `python3 scripts/configure-repository.py --apply` only when those settings need to be restored.

GitHub Actions use pinned dependencies. Do not give forked pull requests credentials or use `pull_request_target` to run contributor code.

## Releases

The public prerelease version in [VERSION](../VERSION) is `0.1.0-beta.1`; the iOS bundle uses numeric `0.1.0` and build `1`. Mark GitHub releases as pre-releases until the project changes that policy. Review signing and Discord SDK terms before distributing a build.
