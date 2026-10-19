#!/bin/zsh
set -euo pipefail

#  ci_pre_xcodebuild.sh
#  sporkcast
#
#  Created by Tom Knighton on 19/12/2025.
#
repository_path="${CI_PRIMARY_REPOSITORY_PATH:-${0:A:h:h}}"
"$repository_path/scripts/validate-ci-environment.sh"

defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES
