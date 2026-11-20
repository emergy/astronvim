import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[2]
FEATURE = ROOT / "devcontainer/features/astronvim"
sys.path.insert(0, str(FEATURE))


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


packager = load("feature_package", ROOT / "scripts/package_devcontainer_feature.py")
setup = load("feature_setup", FEATURE / "setup.py")


class FeatureTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.git("init", "-b", "v5", str(self.repo))
        for key, value in (("user.email", "test@example.invalid"), ("user.name", "Feature Test"),
                           ("commit.gpgsign", "false")):
            self.git("-C", str(self.repo), "config", key, value)
        (self.repo / "init.lua").write_text("-- committed config\n")
        (self.repo / "lua").mkdir()
        (self.repo / "lua/config.lua").write_text("return {}\n")
        (self.repo / "scripts").mkdir()
        helper = self.repo / "scripts/helper"
        helper.write_text("#!/bin/sh\nexit 0\n")
        helper.chmod(0o755)
        (self.repo / "docs").mkdir()
        (self.repo / "docs/private-example.md").write_text("not runtime\n")
        self.git("-C", str(self.repo), "add", ".")
        self.git("-C", str(self.repo), "commit", "-m", "fixture")
        feature = self.repo / "devcontainer/features/astronvim"
        feature.mkdir(parents=True)
        for name in packager.FEATURE_FILES:
            (feature / name).write_bytes((FEATURE / name).read_bytes())
        self.home = self.root / "home"
        self.home.mkdir()
        env = dict(os.environ, HOME=str(self.home))
        for key in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME"):
            env.pop(key, None)
        self.env = patch.dict(os.environ, env, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)

    def git(self, *args):
        return subprocess.check_output(["git", *args], stderr=subprocess.DEVNULL, text=True).strip()

    def bundle(self, name="bundle"):
        target, manifest = packager.bundle(self.repo, self.root / name, "1.0.7")
        source = self.root / (name + "-source")
        source.mkdir()
        # Archives in this test are generated from the fixture's regular files.
        with tarfile.open(target / "config.tar.gz") as archive:
            for member in archive:
                path = source / member.name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(archive.extractfile(member).read())
        return target, source, manifest

    def prepare(self, source, manifest):
        with contextlib.redirect_stdout(io.StringIO()):
            setup.prepare(source, manifest, {"plugins": False}, self.home)

    def test_committed_config_only_and_no_tooling_or_untracked_files(self):
        (self.repo / "init.lua").write_text("uncommitted change")
        (self.repo / "lua/untracked.lua").write_text("not committed")
        target, source, manifest = self.bundle()
        self.assertEqual((source / "init.lua").read_text(), "-- committed config\n")
        self.assertFalse((source / "lua/untracked.lua").exists())
        self.assertFalse((source / "docs").exists())
        self.assertEqual(manifest["revision"], self.git("-C", str(self.repo), "rev-parse", "HEAD"))
        self.assertEqual(json.loads((target / "devcontainer-feature.json").read_text())["version"], "1.0.7")

    def test_deterministic_archive(self):
        first, _, _ = self.bundle("one")
        second, _, _ = self.bundle("two")
        self.assertEqual((first / "config.tar.gz").read_bytes(), (second / "config.tar.gz").read_bytes())

    def test_copy_repeat_user_edits_and_empty_volume_target(self):
        _, source, manifest = self.bundle()
        target = self.home / ".config/nvim"
        target.mkdir(parents=True)
        self.prepare(source, manifest)
        (target / "init.lua").write_text("local edit")
        self.prepare(source, manifest)
        self.assertEqual((target / "init.lua").read_text(), "local edit")
        self.assertTrue((self.home / ".cache/nvim").is_dir())
        self.assertEqual((target / "scripts/helper").stat().st_mode & 0o777, 0o755)

    def test_existing_unmanaged_config_is_preserved(self):
        _, source, manifest = self.bundle()
        target = self.home / ".config/nvim"
        target.mkdir(parents=True)
        (target / "init.lua").write_text("mine")
        with self.assertRaisesRegex(RuntimeError, "unmanaged"):
            self.prepare(source, manifest)
        self.assertEqual((target / "init.lua").read_text(), "mine")

    def test_changed_image_preserves_old_managed_config(self):
        _, source, manifest = self.bundle()
        self.prepare(source, manifest)
        manifest["revision"] = "0" * 40
        self.prepare(source, manifest)
        state = self.home / ".local/share/astronvim-feature/state.json"
        self.assertNotEqual(json.loads(state.read_text())["revision"], manifest["revision"])

    def test_bad_checksum_does_not_create_partial_config(self):
        _, source, manifest = self.bundle()
        (source / "init.lua").write_text("corrupted")
        with self.assertRaisesRegex(RuntimeError, "checksum"):
            self.prepare(source, manifest)
        self.assertFalse((self.home / ".config/nvim").exists())

    def test_manifest_path_traversal_rejected(self):
        _, source, manifest = self.bundle()
        manifest["files"][0]["path"] = "../outside"
        with self.assertRaisesRegex(RuntimeError, "path"):
            self.prepare(source, manifest)

    def test_symlink_in_git_runtime_rejected(self):
        (self.repo / "lua/link.lua").symlink_to("../../outside")
        self.git("-C", str(self.repo), "add", "lua/link.lua")
        self.git("-C", str(self.repo), "commit", "-m", "link fixture")
        with self.assertRaisesRegex(ValueError, "regular"):
            self.bundle()

    def test_invalid_version_and_existing_output_rejected(self):
        with self.assertRaisesRegex(ValueError, "version"):
            packager.bundle(self.repo, self.root / "bundle", "latest")
        self.bundle()
        with self.assertRaisesRegex(ValueError, "exists"):
            self.bundle()

    def test_plugin_failure_leaves_retryable_state(self):
        _, source, manifest = self.bundle()
        with patch.object(setup, "plugins", side_effect=RuntimeError("offline")):
            with self.assertRaisesRegex(RuntimeError, "offline"):
                setup.prepare(source, manifest, {"plugins": True}, self.home)
        state = self.home / ".local/share/astronvim-feature/state.json"
        self.assertFalse(json.loads(state.read_text())["plugins_ready"])
        with patch.object(setup, "plugins") as retry:
            with contextlib.redirect_stdout(io.StringIO()):
                setup.prepare(source, manifest, {"plugins": True}, self.home)
            retry.assert_called_once()


if __name__ == "__main__":
    unittest.main()
