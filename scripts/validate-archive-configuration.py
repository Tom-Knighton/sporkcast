#!/usr/bin/env python3
import argparse
import os
from pathlib import Path
import plistlib
import sys


SERVICE_SETTINGS = (
    "INVITE_HOST", "API_URL", "SUPABASE_URL", "SUPABASE_PUBLIC_KEY",
    "REVENUECAT_API_KEY", "LAUNCHDARKLY_MOBILE_KEY",
)
RUNTIME_SETTINGS = SERVICE_SETTINGS + (
    "ENVIRONMENT", "APP_GROUP", "URL_SCHEME", "KEYCHAIN_SERVICE",
)


def validate_archive(archive, environment):
    applications = list((archive / "Products/Applications").glob("*.app"))
    if len(applications) != 1:
        return ["Expected one app in the Xcode archive's Products/Applications directory."]

    app = applications[0]
    errors = []
    for bundle in [app, *sorted((app / "PlugIns").glob("*.appex"))]:
        try:
            with (bundle / "Info.plist").open("rb") as source:
                info = plistlib.load(source)
        except (OSError, ValueError, plistlib.InvalidFileException):
            errors.append(f"Cannot read {bundle.name}/Info.plist.")
            continue

        for setting in RUNTIME_SETTINGS:
            key = f"SPORKCAST_{setting}"
            value = info.get(key)
            if not isinstance(value, str) or not value.strip() or "$(" in value:
                errors.append(f"{bundle.name}/Info.plist has missing or unresolved {key}.")
                continue
            expected = environment.get(f"SPORKCAST_CI_{setting}")
            if expected and value != expected:
                errors.append(f"{bundle.name}/Info.plist {key} does not match the CI configuration.")

        if info.get("SPORKCAST_ENVIRONMENT") != "production":
            errors.append(f"{bundle.name} is not configured for production.")

    return errors


def main():
    parser = argparse.ArgumentParser(description="Validate bundled configuration without printing its values.")
    parser.add_argument("archive", type=Path)
    args = parser.parse_args()
    errors = validate_archive(args.archive, os.environ)
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    if errors:
        return 1
    print("Production configuration verified in the archived app and extensions.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
