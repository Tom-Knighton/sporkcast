#!/usr/bin/env python3
import importlib.util
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("archive_configuration", ROOT / "scripts/validate-archive-configuration.py")
archive_configuration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(archive_configuration)


def service_environment():
    return {
        "SPORKCAST_CI_INVITE_HOST": "join.production.sporkast.test",
        "SPORKCAST_CI_API_URL": "https://api.production.sporkast.test/",
        "SPORKCAST_CI_SUPABASE_URL": "https://db.production.sporkast.test",
        "SPORKCAST_CI_SUPABASE_PUBLIC_KEY": "sb_publishable_fixture",
        "SPORKCAST_CI_REVENUECAT_API_KEY": "appl_fixture",
        "SPORKCAST_CI_LAUNCHDARKLY_MOBILE_KEY": "mob-private-fixture",
    }


class CloudPreflightTests(unittest.TestCase):
    def run_check(self, values=None, **overrides):
        env = {
            "PATH": os.environ["PATH"],
            "CI_XCODE_CLOUD": "TRUE",
            "CI_XCODE_SCHEME": "sporkcast Production",
            "CI_XCODEBUILD_ACTION": "archive",
        }
        env.update(service_environment() if values is None else values)
        env.update(overrides)
        return subprocess.run([str(ROOT / "scripts/validate-ci-environment.sh")],
                              env=env, capture_output=True, text=True)

    def test_correct_names_pass(self):
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_unprefixed_key_is_rejected_even_when_its_value_is_correct(self):
        values = service_environment()
        values["SPORKCAST_LAUNCHDARKLY_MOBILE_KEY"] = values.pop("SPORKCAST_CI_LAUNCHDARKLY_MOBILE_KEY")
        result = self.run_check(values)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Rename the Xcode Cloud variable SPORKCAST_LAUNCHDARKLY_MOBILE_KEY to SPORKCAST_CI_LAUNCHDARKLY_MOBILE_KEY", result.stderr)
        self.assertNotIn("mob-private-fixture", result.stderr + result.stdout)

    def test_cloud_prebuild_hook_rejects_the_name_mismatch(self):
        values = service_environment()
        values["SPORKCAST_LAUNCHDARKLY_MOBILE_KEY"] = values.pop("SPORKCAST_CI_LAUNCHDARKLY_MOBILE_KEY")
        env = {"PATH": os.environ["PATH"], "CI_XCODE_CLOUD": "TRUE", "CI_XCODE_SCHEME": "sporkcast Production",
               "CI_XCODEBUILD_ACTION": "archive", "CI_PRIMARY_REPOSITORY_PATH": str(ROOT)} | values
        result = subprocess.run([str(ROOT / "ci_scripts/ci_pre_xcodebuild.sh")],
                                env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Rename", result.stderr)
        self.assertNotIn("mob-private-fixture", result.stderr + result.stdout)

    def test_all_missing_names_are_reported_without_values(self):
        result = self.run_check({})
        self.assertNotEqual(result.returncode, 0)
        for key in service_environment():
            self.assertIn(key, result.stderr)

    def test_original_scheme_archives_still_require_production_configuration(self):
        result = self.run_check({}, CI_XCODE_SCHEME="sporkcast")
        self.assertNotEqual(result.returncode, 0)

    def test_dev_builds_and_local_builds_need_no_cloud_variables(self):
        for overrides in [dict(CI_XCODE_SCHEME="sporkcast", CI_XCODEBUILD_ACTION="build"),
                          dict(CI_XCODE_CLOUD="")]:
            with self.subTest(overrides=overrides):
                self.assertEqual(self.run_check({}, **overrides).returncode, 0)


class ArchiveConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.archive = Path(self.temporary.name) / "Sporkcast.xcarchive"
        self.app = self.archive / "Products/Applications/sporkcast.app"
        self.bundles = [self.app] + [self.app / "PlugIns" / f"{name}.appex"
                                    for name in ["countdownextension", "recipeShareExtension", "recipeShareServiceExtension"]]
        for bundle in self.bundles:
            bundle.mkdir(parents=True)
            info = {key.replace("SPORKCAST_CI_", "SPORKCAST_", 1): value
                    for key, value in service_environment().items()}
            info.update(SPORKCAST_ENVIRONMENT="production", SPORKCAST_APP_GROUP="group.sporkcast.production",
                        SPORKCAST_URL_SCHEME="sporkcast", SPORKCAST_KEYCHAIN_SERVICE="online.tomk.sporkcast.production.supabase")
            self.write_info(bundle, info)

    def write_info(self, bundle, info):
        with (bundle / "Info.plist").open("wb") as output:
            plistlib.dump(info, output, fmt=plistlib.FMT_BINARY)

    def change_info(self, bundle, **changes):
        with (bundle / "Info.plist").open("rb") as source:
            info = plistlib.load(source)
        info.update(changes)
        self.write_info(bundle, info)

    def test_complete_archive_passes(self):
        self.assertEqual(archive_configuration.validate_archive(self.archive, service_environment()), [])

    def test_missing_bundled_value_fails_despite_valid_shell_environment(self):
        self.change_info(self.app, SPORKCAST_LAUNCHDARKLY_MOBILE_KEY="")
        errors = archive_configuration.validate_archive(self.archive, service_environment())
        self.assertTrue(any("SPORKCAST_LAUNCHDARKLY_MOBILE_KEY" in error for error in errors))
        self.assertNotIn("mob-private-fixture", "\n".join(errors))

    def test_every_extension_is_checked(self):
        for bundle in self.bundles[1:]:
            self.change_info(bundle, SPORKCAST_LAUNCHDARKLY_MOBILE_KEY="$(SPORKCAST_CI_LAUNCHDARKLY_MOBILE_KEY)")
        errors = archive_configuration.validate_archive(self.archive, service_environment())
        for bundle in self.bundles[1:]:
            self.assertTrue(any(bundle.name in error for error in errors))

    def test_mismatched_bundled_value_fails_without_disclosing_values(self):
        self.change_info(self.app, SPORKCAST_LAUNCHDARKLY_MOBILE_KEY="mob-wrong-fixture")
        errors = archive_configuration.validate_archive(self.archive, service_environment())
        self.assertTrue(any("does not match" in error for error in errors))
        self.assertNotIn("mob-private-fixture", "\n".join(errors))
        self.assertNotIn("mob-wrong-fixture", "\n".join(errors))

    def test_dev_archive_is_rejected(self):
        self.change_info(self.app, SPORKCAST_ENVIRONMENT="development")
        self.assertTrue(archive_configuration.validate_archive(self.archive, service_environment()))

    def test_missing_archive_is_rejected(self):
        self.assertTrue(archive_configuration.validate_archive(self.archive / "missing", service_environment()))

    def test_cloud_post_archive_hook_checks_the_packaged_plist(self):
        self.change_info(self.app, SPORKCAST_LAUNCHDARKLY_MOBILE_KEY="")
        env = {"PATH": os.environ["PATH"], "CI_XCODE_CLOUD": "TRUE", "CI_XCODEBUILD_ACTION": "archive",
               "CI_XCODEBUILD_EXIT_CODE": "0", "CI_ARCHIVE_PATH": str(self.archive),
               "CI_PRIMARY_REPOSITORY_PATH": str(ROOT)} | service_environment()
        result = subprocess.run([str(ROOT / "ci_scripts/ci_post_xcodebuild.sh")],
                                env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("SPORKCAST_LAUNCHDARKLY_MOBILE_KEY", result.stderr)
        self.assertNotIn("mob-private-fixture", result.stderr + result.stdout)


if __name__ == "__main__":
    unittest.main()
