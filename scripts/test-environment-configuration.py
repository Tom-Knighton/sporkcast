#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]


def configuration(environment):
    suffix = f".{environment}"
    scheme_suffix = "" if environment == "production" else f"-{environment}"
    return {
        "SPORKCAST_ENVIRONMENT": environment,
        "SPORKCAST_BUNDLE_ID": "online.tomk.sporkcast" if environment == "production" else f"online.tomk.sporkcast{suffix}",
        "SPORKCAST_APP_GROUP": f"group.sporkcast{suffix}",
        "SPORKCAST_URL_SCHEME": f"sporkcast{scheme_suffix}",
        "SPORKCAST_KEYCHAIN_SERVICE": f"online.tomk.sporkcast{suffix}.supabase",
        "SPORKCAST_ICLOUD_CONTAINER": f"iCloud.online.tomk.sporkcast{suffix}",
        "SPORKCAST_ICLOUD_KVSTORE": f"online.tomk.sporkcast{suffix}",
        "SPORKCAST_INVITE_HOST": f"join.{environment}.sporkast.test",
        "SPORKCAST_API_URL": f"https://api.{environment}.sporkast.test/",
        "SPORKCAST_SUPABASE_URL": f"https://db.{environment}.sporkast.test",
        "SPORKCAST_SUPABASE_PUBLIC_KEY": "sb_publishable_fixture",
        "SPORKCAST_REVENUECAT_API_KEY": "appl_fixture",
        "SPORKCAST_LAUNCHDARKLY_MOBILE_KEY": "mob-fixture",
    }


class EnvironmentConfigurationTests(unittest.TestCase):
    def validate(self, environment="production", **overrides):
        values = configuration(environment) | overrides
        return subprocess.run(
            [str(ROOT / "scripts/validate-environment.sh")],
            env={"PATH": os.environ["PATH"]} | values,
            capture_output=True, text=True,
        )

    def test_schemes_select_the_expected_configuration(self):
        for scheme, run, archive in [("sporkcast", "Debug", "Release"),
                                      ("sporkcast Production", "Release", "Release")]:
            with self.subTest(scheme=scheme):
                tree = ET.parse(ROOT / f"sporkcast.xcodeproj/xcshareddata/xcschemes/{scheme}.xcscheme")
                self.assertEqual(tree.find("LaunchAction").get("buildConfiguration"), run)
                self.assertEqual(tree.find("ArchiveAction").get("buildConfiguration"), archive)

    def test_valid_environments(self):
        for environment in ["development", "production"]:
            with self.subTest(environment=environment):
                result = self.validate(environment)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_every_required_value_is_checked(self):
        for name in configuration("production"):
            with self.subTest(name=name):
                result = self.validate(**{name: ""})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(name, result.stderr)

    def test_unresolved_build_setting_is_rejected(self):
        result = self.validate(SPORKCAST_API_URL="$(SPORKCAST_API_URL)")
        self.assertNotEqual(result.returncode, 0)

    def test_test_store_is_only_allowed_in_development(self):
        for environment in ["development", "production"]:
            result = self.validate(environment, SPORKCAST_REVENUECAT_API_KEY="test_fixture")
            self.assertEqual(result.returncode == 0, environment == "development")

    def test_distribution_cannot_use_development_services(self):
        for name, value in {
            "SPORKCAST_API_URL": "https://api.dev.recipe.tomk.online/",
            "SPORKCAST_SUPABASE_URL": "https://db.sporkast.dev.tomk.online",
            "SPORKCAST_INVITE_HOST": "join.dev.sporkast.test",
            "SPORKCAST_SUPABASE_PUBLIC_KEY": "sb_publishable_tyZO5jlR3XGvNuNHGOKDpe_Xms05kQF",
            "SPORKCAST_LAUNCHDARKLY_MOBILE_KEY": "mob-0e75d9dd-fb2e-4080-b627-83dfaf403079",
        }.items():
            with self.subTest(name=name):
                self.assertNotEqual(self.validate(**{name: value}).returncode, 0)

    def test_unsupported_environment_is_rejected(self):
        self.assertNotEqual(self.validate(SPORKCAST_ENVIRONMENT="staging").returncode, 0)

    def test_distribution_cannot_share_development_storage_or_links(self):
        for name in ["SPORKCAST_BUNDLE_ID", "SPORKCAST_APP_GROUP", "SPORKCAST_URL_SCHEME",
                     "SPORKCAST_KEYCHAIN_SERVICE", "SPORKCAST_ICLOUD_CONTAINER", "SPORKCAST_ICLOUD_KVSTORE"]:
            with self.subTest(name=name):
                self.assertNotEqual(self.validate(**{name: configuration("development")[name]}).returncode, 0)

    def test_extension_identifier_must_belong_to_the_app(self):
        result = self.validate(PRODUCT_BUNDLE_IDENTIFIER="online.tomk.sporkcast.recipeShareExtension")
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.validate(PRODUCT_BUNDLE_IDENTIFIER="online.tomk.sporkcast.development.recipeShareExtension")
        self.assertNotEqual(result.returncode, 0)

    def test_development_cannot_be_archived(self):
        self.assertNotEqual(self.validate("development", ACTION="install").returncode, 0)

    def test_insecure_or_placeholder_service_urls_are_rejected(self):
        for value in ["http://api.sporkast.test", "https://example.com", "https://localhost", "https://api.invalid", "https://api.sporkast.test/has space"]:
            with self.subTest(value=value):
                self.assertNotEqual(self.validate(SPORKCAST_API_URL=value).returncode, 0)


@unittest.skipUnless(os.environ.get("RUN_XCODE_CONFIGURATION_TESTS") == "1", "Set RUN_XCODE_CONFIGURATION_TESTS=1 to check Xcode settings")
class XcodeEnvironmentExpansionTests(unittest.TestCase):
    def settings(self, build_configuration, ci_environment=None):
        env = {key: value for key, value in os.environ.items() if not key.startswith("SPORKCAST_")}
        if ci_environment:
            for key, value in configuration(ci_environment).items():
                if key in {"SPORKCAST_INVITE_HOST", "SPORKCAST_API_URL", "SPORKCAST_SUPABASE_URL",
                           "SPORKCAST_SUPABASE_PUBLIC_KEY", "SPORKCAST_REVENUECAT_API_KEY",
                           "SPORKCAST_LAUNCHDARKLY_MOBILE_KEY"}:
                    env[key.replace("SPORKCAST_", "SPORKCAST_CI_", 1)] = value
        result = subprocess.run(
            ["xcodebuild", "-project", "sporkcast.xcodeproj", "-alltargets", "-configuration",
             build_configuration, "-sdk", "iphonesimulator", "-showBuildSettings", "-json"],
            cwd=ROOT, env=env, capture_output=True, text=True, timeout=120,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_ci_values_reach_the_app_and_every_extension(self):
        targets = self.settings("Release", "production")
        self.assertEqual(len({item["target"] for item in targets}), 4)
        for item in targets:
            settings = item["buildSettings"]
            for key in ["SPORKCAST_API_URL", "SPORKCAST_SUPABASE_URL", "SPORKCAST_SUPABASE_PUBLIC_KEY",
                        "SPORKCAST_INVITE_HOST", "SPORKCAST_REVENUECAT_API_KEY", "SPORKCAST_LAUNCHDARKLY_MOBILE_KEY"]:
                self.assertEqual(settings[key], configuration("production")[key], (item["target"], key))
            values = {key: str(value) for key, value in settings.items() if isinstance(value, str)}
            result = subprocess.run([str(ROOT / "scripts/validate-environment.sh")],
                                    env=values, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_ci_values_do_not_change_local_development(self):
        for item in self.settings("Debug", "production"):
            settings = item["buildSettings"]
            self.assertEqual(settings["SPORKCAST_ENVIRONMENT"], "development")
            self.assertEqual(settings["SPORKCAST_API_URL"], "https://api.dev.recipe.tomk.online/")
            self.assertTrue(settings["SPORKCAST_REVENUECAT_API_KEY"].startswith("test_"))

    def test_missing_ci_values_fail_validation(self):
        for item in self.settings("Release"):
            values = {key: str(value) for key, value in item["buildSettings"].items() if isinstance(value, str)}
            result = subprocess.run([str(ROOT / "scripts/validate-environment.sh")],
                                    env=values, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("SPORKCAST_INVITE_HOST", result.stderr)


if __name__ == "__main__":
    unittest.main()
