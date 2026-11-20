#!/usr/bin/env python3
"""Install the bundled config as the container user without cloning Git."""

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

from plugins import plugins


def verify_source(source, manifest):
    paths = []
    for entry in manifest["files"]:
        relative = Path(entry["path"])
        if relative.is_absolute() or ".." in relative.parts:
            raise RuntimeError("invalid bundled configuration path")
        path = source / relative
        if path.is_symlink() or not path.is_file():
            raise RuntimeError("missing or linked bundled file: " + str(relative))
        if hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
            raise RuntimeError("bundled configuration checksum mismatch: " + str(relative))
        paths.append((path, relative, entry["mode"]))
    if not any(relative == Path("init.lua") for _, relative, _ in paths):
        raise RuntimeError("bundled configuration has no init.lua")
    return paths


def prepare(source, manifest, settings, home):
    config = Path(os.environ.get("XDG_CONFIG_HOME", str(home / ".config"))) / "nvim"
    data = Path(os.environ.get("XDG_DATA_HOME", str(home / ".local/share"))) / "astronvim-feature"
    data.mkdir(parents=True, exist_ok=True)
    with (data / "setup.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        install_config(source, manifest, settings, home, config, data)


def install_config(source, manifest, settings, home, target, data):
    state = data / "state.json"
    if state.exists():
        record = json.loads(state.read_text())
        if not (target / "init.lua").is_file():
            raise RuntimeError("managed configuration disappeared; inspect the config and feature state")
        if record["revision"] != manifest["revision"]:
            print("Keeping existing config from {} (image bundles {}); use a fresh config/state to apply it".format(
                record["revision"], manifest["revision"]))
            return
        if settings["plugins"] and not record.get("plugins_ready"):
            plugins(settings, target, state, record)
        print("AstroNvim configuration already installed; local edits preserved")
        return
    if target.is_symlink() or target.exists() and (not target.is_dir() or any(target.iterdir())):
        raise RuntimeError("existing unmanaged Neovim configuration will not be overwritten: " + str(target))
    files = verify_source(source, manifest)
    target.mkdir(parents=True, exist_ok=True)
    for original, relative, mode in files:
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open("xb") as output:
            output.write(original.read_bytes())
        destination.chmod(mode)
    for variable, fallback in (("XDG_CACHE_HOME", home / ".cache"),
                               ("XDG_STATE_HOME", home / ".local/state"),
                               ("XDG_DATA_HOME", home / ".local/share")):
        (Path(os.environ.get(variable, str(fallback))) / "nvim").mkdir(parents=True, exist_ok=True)
    record = {"revision": manifest["revision"], "plugins_ready": False}
    state.write_text(json.dumps(record, indent=2) + "\n")
    if settings["plugins"]:
        plugins(settings, target, state, record)
    print("Installed bundled AstroNvim config " + manifest["revision"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default="/usr/local/share/astronvim/config")
    parser.add_argument("--manifest", default="/usr/local/share/astronvim/config-source.json")
    parser.add_argument("--settings", default="/usr/local/share/astronvim/settings.json")
    args = parser.parse_args()
    try:
        prepare(Path(args.source), json.loads(Path(args.manifest).read_text()),
                json.loads(Path(args.settings).read_text()), Path.home())
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        print("astronvim-setup: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
