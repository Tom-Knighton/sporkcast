#!/bin/bash
set -euo pipefail

[[ "${CI_XCODE_CLOUD:-}" == TRUE ]] || exit 0
if [[ "${CI_XCODE_SCHEME:-}" != 'sporkcast Production' && "${CI_XCODEBUILD_ACTION:-}" != archive ]]; then
    exit 0
fi

missing=0
for setting in INVITE_HOST API_URL SUPABASE_URL SUPABASE_PUBLIC_KEY REVENUECAT_API_KEY LAUNCHDARKLY_MOBILE_KEY; do
    variable="SPORKCAST_CI_$setting"
    if [[ -z "${!variable:-}" ]]; then
        unprefixed="SPORKCAST_$setting"
        if [[ -n "${!unprefixed:-}" ]]; then
            echo "error: Rename the Xcode Cloud variable $unprefixed to $variable. Keep Secret enabled." >&2
        else
            echo "error: Add $variable to the production Xcode Cloud workflow environment." >&2
        fi
        missing=1
    fi
done
exit "$missing"
