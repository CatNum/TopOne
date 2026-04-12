#!/usr/bin/env bash
set -euo pipefail
xcodebuild -project "TopOne.xcodeproj" -scheme "TopOnemacOS" -configuration Debug -destination "platform=macOS" test
