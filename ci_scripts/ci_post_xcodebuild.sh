#!/bin/zsh
set -euo pipefail

if [[ "${CI_XCODE_CLOUD:-}" != TRUE || "${CI_XCODEBUILD_ACTION:-}" != archive || "${CI_XCODEBUILD_EXIT_CODE:-1}" != 0 ]]; then
    exit 0
fi

if [[ -z "${CI_ARCHIVE_PATH:-}" ]]; then
    echo "error: Xcode Cloud did not provide CI_ARCHIVE_PATH for the completed archive." >&2
    exit 1
fi

repository_path="${CI_PRIMARY_REPOSITORY_PATH:-${0:A:h:h}}"
python3 "$repository_path/scripts/validate-archive-configuration.py" "$CI_ARCHIVE_PATH"
