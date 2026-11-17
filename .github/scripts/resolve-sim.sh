#!/bin/bash
# Resolve an iPhone 17 simulator destination; fail hard if unavailable.
# Also materialise root Secrets.xcconfig (referenced by the pbxproj) from the example if missing.
set -euo pipefail
[ -f Secrets.xcconfig ] || cp Config/Secrets.xcconfig.example Secrets.xcconfig
DEST=$(xcodebuild -showdestinations -scheme tracker 2>/dev/null \
  | grep "platform:iOS Simulator" | grep "name:iPhone 17," | head -1 \
  | sed -n 's/.*id:\([^,}]*\).*/\1/p' | tr -d ' ')
if [ -z "$DEST" ]; then
  echo "::error::No 'iPhone 17' iOS simulator found (platform=iOS Simulator,name=iPhone 17)"
  xcodebuild -showdestinations -scheme tracker || true
  exit 1
fi
echo "destination=platform=iOS Simulator,id=$DEST" >> "$GITHUB_OUTPUT"
