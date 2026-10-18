# Build environments

The project has two environments. TestFlight and the App Store use the same production configuration and App Store Connect app.

| Environment | Scheme | Configuration | App bundle ID | Services |
| --- | --- | --- | --- | --- |
| Development | `sporkcast` | Debug | `online.tomk.sporkcast.development` | Dev API/database, RevenueCat Test Store, dev LaunchDarkly |
| Production | `sporkcast Production` | Release | `online.tomk.sporkcast` | Production API/database, RevenueCat Apple app, production LaunchDarkly |

Daily development still uses the existing `sporkcast` scheme and Run action. No CI variables, endpoint edits, branch changes, or scheme switching are required.

The production bundle ID is retained. Development has a separate identity: the first Run installs **Sporkcast Dev** alongside the old app, with a fresh database, settings, and login. Existing on-device data remains in the old app; export recipes there and import them into Sporkcast Dev if needed. Do not delete the old app before exporting anything you want to retain.

Production uses `Sporkcast.production.sqlite` rather than the legacy `Sporkcast.sqlite` file, so installing production over an old dev build cannot open and upload that build's local recipes. The legacy file remains untouched. App Groups, auth keychain services, CloudKit containers, iCloud key-value stores, and URL schemes are isolated between dev and production.

## Release flow

1. Select `sporkcast Production`, archive, and upload using normal **App Store Connect** distribution.
2. Test the uploaded build through TestFlight. It uses production services; testers' data is production data. Purchases use Apple's sandbox through the RevenueCat Apple app key.
3. Select that exact uploaded build for the App Store version, supply release metadata, and submit for App Review. No rebuild or environment change is needed.

Do not select **TestFlight Internal Only** distribution for a build you intend to release: those uploads are ineligible for App Store release. See [Apple's distribution guide](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases/) and [beta testing guide](https://developer.apple.com/tutorials/develop-in-swift/test-your-beta-app).

The original `sporkcast` scheme also archives using Release, so its archive is production-configured. The explicitly named production scheme makes the release choice clearer.

## One-time Apple setup

1. Keep the existing App Store Connect app and `online.tomk.sporkcast` production identifier. No second App Store Connect app is required.
2. Register the development app identifier and its extensions. Both environments use `.countdownextension`, `.recipeShareExtension`, and `.recipeShareServiceExtension` extension suffixes. Production extension bundle IDs remain unchanged.
3. Associate `group.sporkcast.development` and `group.sporkcast.production` with their respective apps and all three extensions.
4. Associate CloudKit containers `iCloud.online.tomk.sporkcast.development` and `iCloud.online.tomk.sporkcast.production` with their respective apps. Local builds use the Development CloudKit environment; production distribution uses Production.
5. Enable the project's capabilities, including iCloud key-value storage, WeatherKit, push notifications, and associated domains, and refresh automatic provisioning. Production push entitlements use `production`.
6. Configure each invite domain's AASA file for its app bundle ID and `/join/*` paths. Use separate dev and production domains for reliable routing. The dev domain remains unchanged.

## Production configuration from CI

`Configuration/Development.xcconfig` is ready to use and ignores CI service variables. `Configuration/Production.xcconfig` reads public service configuration directly from the build process environment:

```xcconfig
SPORKCAST_API_URL = $(SPORKCAST_CI_API_URL)
```

Set these six variables in the production CI environment:

| Variable | Value |
| --- | --- |
| `SPORKCAST_CI_INVITE_HOST` | Invite hostname, without a scheme or path |
| `SPORKCAST_CI_API_URL` | Full HTTPS API URL |
| `SPORKCAST_CI_SUPABASE_URL` | Full HTTPS Supabase URL |
| `SPORKCAST_CI_SUPABASE_PUBLIC_KEY` | Supabase public/publishable key |
| `SPORKCAST_CI_REVENUECAT_API_KEY` | Existing RevenueCat Apple app key (`appl_`) for `online.tomk.sporkcast` |
| `SPORKCAST_CI_LAUNCHDARKLY_MOBILE_KEY` | Production LaunchDarkly mobile key (`mob-`) |

CI generates no configuration files and passes no values on the command line. Xcode embeds the resolved values in the app and extension Info.plists. Missing values block the build.

Environment variable URLs use ordinary `https://` syntax. Include only public client keys: these values are readable from the distributed app. Server/service-role secrets belong on the server. Dev public keys remain checked in to preserve local development; removing keys from the current production configuration does not remove previously committed copies from Git history.

Provision the production API, Supabase database/auth configuration, invite domain, and LaunchDarkly environment independently of dev, and apply backend/database migrations. The app does not create those services. Dev retains its RevenueCat Test Store; production uses the existing RevenueCat Apple app, offerings, and `Sporkast Pro` entitlement. TestFlight sandbox purchases must not grant production backend entitlements if server-side purchase validation is added.

### Xcode Cloud

Use one distribution workflow with the `sporkcast Production` scheme. Add the six variables above to the workflow's Environment settings and mark their values **Secret / Keep value redacted**. Select Archive and configure distribution to the existing app's TestFlight. After testing, submit the same build for App Store review.

No changes to `ci_pre_xcodebuild.sh` are required; Xcode reads the workflow variables directly. Apple documents [workflow environment variables](https://developer.apple.com/documentation/xcode/xcode-cloud-workflow-reference). Do not print the environment or run `xcodebuild -showBuildSettings` in CI logs with real values. The project's validation phases have environment logging disabled.

### GitHub Actions

Create a GitHub environment named `production` under repository Settings → Environments. Add the six names above as environment secrets. The checked-in `.github/workflows/ios-environment-build.yml` passes those secrets directly into the build process environment.

Run **iOS production build** manually from the Actions tab. It runs configuration checks and compiles an unsigned simulator build. Signing and TestFlight distribution remain Xcode Cloud responsibilities. The workflow has no automatic PR trigger. Restrict production secrets to trusted release branches through GitHub environment settings.

The workflow uses GitHub's [`xcode-27` runner](https://github.com/actions/runner-images/issues/14404) for this project's SDK 27 APIs. That runner is currently a preview. To select a particular installed Xcode, set the GitHub configuration variable `XCODE_DEVELOPER_DIR` to its `Contents/Developer` path; otherwise the runner's `/Applications/Xcode.app/Contents/Developer` is used.

### Local production archives

Export the same six CI variables before invoking command-line `xcodebuild`, or use the optional ignored `Configuration/Production.local.xcconfig` for archives in Xcode. CI never creates or needs that file. Literal URLs written into xcconfig must escape `//` as `https:/$()/host`.

## Validation

Every app and extension target runs `scripts/validate-environment.sh`. It rejects missing configuration, malformed URLs, dev services/keys in production, RevenueCat Test Store keys in production, and incorrect storage/identity namespaces. Explicit Debug archives are rejected. It does not check service availability or Apple dashboard configuration.

`AppConfiguration` reads the built Info.plist rather than launch environment variables. Debug-only dev defaults support package tests and previews whose host lacks the app's Info.plist. Release code has no fallback to dev.

Run guard regression tests:

```sh
python3 scripts/test-environment-configuration.py
```

Also verify real Xcode environment expansion for dev, production, all extensions, and missing configuration using fixture values without contacting services:

```sh
RUN_XCODE_CONFIGURATION_TESTS=1 python3 scripts/test-environment-configuration.py
```
