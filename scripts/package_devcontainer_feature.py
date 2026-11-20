#!/usr/bin/env python3
"""Assemble an OCI feature with runtime config from an exact Git commit."""

import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile


RUNTIME_FILES = {"init.lua", "lazy-lock.json", ".luarc.json", ".neoconf.json", ".stylua.toml"}
RUNTIME_DIRS = {"lua", "after", "queries", "snippets", "syntax", "colors", "ftplugin",
                "ftdetect", "lsp", "spell", "scripts", "terminal", "tmux"}
FEATURE_FILES = ("devcontainer-feature.json", "install.sh", "install-tools.py", "setup.py", "plugins.py", "README.md")


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args])


def runtime_files(root, revision):
    records = git(root, "ls-tree", "-r", "-z", revision).split(b"\0")
    result = []
    for record in records:
        if not record:
            continue
        header, raw_path = record.split(b"\t", 1)
        mode, kind, object_id = header.decode().split()
        path = raw_path.decode("utf-8")
        if path not in RUNTIME_FILES and path.split("/", 1)[0] not in RUNTIME_DIRS:
            continue
        # The packaging script itself belongs to tooling, not editor runtime.
        if path == "scripts/package_devcontainer_feature.py":
            continue
        if kind != "blob" or mode not in {"100644", "100755"}:
            raise ValueError("runtime config must contain regular tracked files: " + path)
        if Path(path).is_absolute() or ".." in Path(path).parts:
            raise ValueError("invalid tracked runtime path")
        result.append((path, int(mode, 8) & 0o777, git(root, "cat-file", "blob", object_id)))
    if not any(path == "init.lua" for path, _, _ in result):
        raise ValueError("selected commit contains no tracked init.lua")
    return sorted(result)


def bundle(root, output, version, revision="HEAD"):
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("feature version must be numeric major.minor.patch")
    commit = git(root, "rev-parse", "--verify", revision + "^{commit}").decode().strip()
    files = runtime_files(root, commit)
    target = output / "astronvim"
    if target.exists():
        raise ValueError("output already exists: " + str(target))
    target.mkdir(parents=True)
    source = root / "devcontainer/features/astronvim"
    for name in FEATURE_FILES:
        shutil.copy2(source / name, target / name)
    metadata_path = target / "devcontainer-feature.json"
    metadata = json.loads(metadata_path.read_text())
    metadata["version"] = version
    metadata["description"] = "Neovim and emergy/AstroNvim config at " + commit
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n")
    with (target / "config.tar.gz").open("wb") as raw:
        with gzip.GzipFile(filename="", fileobj=raw, mode="wb", mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode="w") as archive:
                for path, mode, content in files:
                    info = tarfile.TarInfo(path)
                    info.mode, info.size, info.mtime = mode, len(content), 0
                    archive.addfile(info, io.BytesIO(content))
    manifest = {"revision": commit, "files": [
        {"path": path, "mode": mode, "sha256": hashlib.sha256(content).hexdigest()}
        for path, mode, content in files
    ]}
    (target / "config-source.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return target, manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--revision", default="HEAD")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    target, manifest = bundle(root, args.output.resolve(), args.version, args.revision)
    print("Feature: {}\nConfiguration commit: {}\nFiles: {}".format(
        target, manifest["revision"], len(manifest["files"])))


if __name__ == "__main__":
    main()
