#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
spec=project.yml
if [[ "${AIZU_WITHOUT_SDK:-0}" != "1" && -d Vendor/discord_partner_sdk.xcframework ]]; then
  cat > .project-local.yml <<'EOF'
include: project.yml
targets:
  AIZU:
    dependencies:
      - framework: Vendor/discord_partner_sdk.xcframework
        embed: true
    settings:
      base:
        GCC_PREPROCESSOR_DEFINITIONS: '$(inherited) PRESENCE_DISCORD_SDK=1'
EOF
  spec=.project-local.yml
fi
if ! command -v xcodegen >/dev/null 2>&1; then
  print -u2 "XcodeGen is required. Install it with: brew install xcodegen"
  exit 1
fi
xcodegen generate --spec "$spec"
