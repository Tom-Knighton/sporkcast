#!/bin/zsh
set -euo pipefail

PROJECT_PATH="${1:-sporkcast.xcodeproj}"

open -na "Xcode" "$PROJECT_PATH"
