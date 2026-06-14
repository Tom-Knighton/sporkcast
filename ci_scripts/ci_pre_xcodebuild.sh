#!/bin/zsh
set -euo pipefail

#  ci_pre_xcodebuild.sh
#  sporkcast
#
#  Created by Tom Knighton on 19/12/2025.
#
defaults write com.apple.dt.Xcode IDESkipMacroFingerprintValidation -bool YES

IOS_SDK_VERSION="$(xcrun --sdk iphoneos --show-sdk-version)"

case "${ENABLE_IOS_27_SDK:-NO}" in
  YES|yes|1|true|TRUE)
    if [[ "$IOS_SDK_VERSION" != 27.* ]]; then
      echo "ENABLE_IOS_27_SDK=YES but iphoneos SDK is $IOS_SDK_VERSION"
      exit 1
    fi

    echo "Building with iOS 27 SDK support enabled."
    ;;

  *)
    echo "Building without iOS 27 SDK support. iphoneos SDK is $IOS_SDK_VERSION."
    ;;
esac
