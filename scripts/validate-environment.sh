#!/bin/bash
set -euo pipefail

fail() {
    echo "error: $*" >&2
    exit 1
}

require_value() {
    local name="$1"
    local value="${!name:-}"
    case "$value" in
        ''|*'$('*|*REPLACE*|*YOUR_*|*CHANGE_ME*)
            case "$name" in
                SPORKCAST_INVITE_HOST|SPORKCAST_API_URL|SPORKCAST_SUPABASE_URL|SPORKCAST_SUPABASE_PUBLIC_KEY|SPORKCAST_REVENUECAT_API_KEY|SPORKCAST_LAUNCHDARKLY_MOBILE_KEY)
                    fail "Set SPORKCAST_CI_${name#SPORKCAST_} in the CI environment (or $name in Configuration/$configuration_file.local.xcconfig)." ;;
                *) fail "Set $name in Configuration/$configuration_file.xcconfig." ;;
            esac ;;
    esac
}

case "${SPORKCAST_ENVIRONMENT:-}" in
    development) configuration_file=Development ;;
    production) configuration_file=Production ;;
    *) fail "SPORKCAST_ENVIRONMENT must be development or production." ;;
esac

for name in SPORKCAST_BUNDLE_ID SPORKCAST_APP_GROUP SPORKCAST_URL_SCHEME \
    SPORKCAST_KEYCHAIN_SERVICE SPORKCAST_ICLOUD_CONTAINER SPORKCAST_ICLOUD_KVSTORE \
    SPORKCAST_INVITE_HOST SPORKCAST_API_URL SPORKCAST_SUPABASE_URL \
    SPORKCAST_SUPABASE_PUBLIC_KEY SPORKCAST_REVENUECAT_API_KEY SPORKCAST_LAUNCHDARKLY_MOBILE_KEY; do
    require_value "$name"
done

for name in SPORKCAST_API_URL SPORKCAST_SUPABASE_URL; do
    value="${!name}"
    [[ "$value" =~ ^https://[a-zA-Z0-9][a-zA-Z0-9.-]+(:[0-9]+)?(/[^[:space:]]*)?$ ]] || fail "$name must be an HTTPS URL. In xcconfig files use https:/\$()/host to escape //."
    case "$value" in
        *example.com*|*.invalid*|*localhost*|*127.0.0.1*) fail "$name must point to a configured service." ;;
    esac
done

[[ "$SPORKCAST_INVITE_HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]+$ ]] || fail "SPORKCAST_INVITE_HOST must be a hostname, without a scheme or path."
[[ "$SPORKCAST_URL_SCHEME" =~ ^[a-z][a-z0-9+.-]*$ ]] || fail "SPORKCAST_URL_SCHEME must be a valid URL scheme."
[[ "$SPORKCAST_LAUNCHDARKLY_MOBILE_KEY" == mob-* ]] || fail "Use a LaunchDarkly mobile key for this environment."
case "$SPORKCAST_SUPABASE_PUBLIC_KEY" in
    sb_secret_*) fail "Never embed a Supabase secret key in the app. Use its public/publishable key." ;;
esac

if [[ "$SPORKCAST_ENVIRONMENT" == development ]]; then
    [[ "${ACTION:-}" != install ]] || fail "Development builds cannot be archived for distribution. Select sporkcast Production."
    exit 0
fi

[[ "$SPORKCAST_REVENUECAT_API_KEY" == appl_* ]] || fail "TestFlight and App Store builds require the RevenueCat Apple app key (appl_), not a Test Store key."
[[ "$SPORKCAST_SUPABASE_PUBLIC_KEY" != sb_publishable_tyZO5jlR3XGvNuNHGOKDpe_Xms05kQF ]] || fail "This environment still uses the development Supabase key."
[[ "$SPORKCAST_LAUNCHDARKLY_MOBILE_KEY" != mob-0e75d9dd-fb2e-4080-b627-83dfaf403079 ]] || fail "This environment still uses the development LaunchDarkly key."

for name in SPORKCAST_API_URL SPORKCAST_SUPABASE_URL SPORKCAST_INVITE_HOST; do
    value="${!name}"
    case "$value" in
        *://dev.*|*.dev.*|*://development.*|*.development.*) fail "$name still points to development." ;;
    esac
done

for name in SPORKCAST_KEYCHAIN_SERVICE SPORKCAST_ICLOUD_KVSTORE; do
    [[ "${!name}" == "online.tomk.sporkcast.$SPORKCAST_ENVIRONMENT"* ]] || fail "$name must use the $SPORKCAST_ENVIRONMENT namespace."
done
[[ "$SPORKCAST_APP_GROUP" == "group.sporkcast.$SPORKCAST_ENVIRONMENT" ]] || fail "Use a separate $SPORKCAST_ENVIRONMENT App Group."
[[ "$SPORKCAST_BUNDLE_ID" == online.tomk.sporkcast ]] || fail "Keep the existing production bundle ID."
[[ "$SPORKCAST_URL_SCHEME" == sporkcast ]] || fail "Keep the existing production URL scheme."
[[ "$SPORKCAST_ICLOUD_CONTAINER" == "iCloud.online.tomk.sporkcast.$SPORKCAST_ENVIRONMENT" ]] || fail "Use a separate $SPORKCAST_ENVIRONMENT CloudKit container."

case "${PRODUCT_BUNDLE_IDENTIFIER:-$SPORKCAST_BUNDLE_ID}" in
    "$SPORKCAST_BUNDLE_ID"|"$SPORKCAST_BUNDLE_ID.countdownextension"|"$SPORKCAST_BUNDLE_ID.recipeShareExtension"|"$SPORKCAST_BUNDLE_ID.recipeShareServiceExtension") ;;
    *) fail "The app or extension bundle ID does not match SPORKCAST_BUNDLE_ID." ;;
esac
