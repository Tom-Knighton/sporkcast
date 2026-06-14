#!/bin/zsh
set -euo pipefail

PROJECT_PATH="${1:-sporkcast.xcodeproj}"

ENABLE_IOS_27_SDK=YES open -na "Xcode-beta" "$PROJECT_PATH"
