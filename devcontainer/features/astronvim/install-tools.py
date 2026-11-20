#!/usr/bin/env python3
"""Image-build tools; downloads are verified before execution or extraction."""

import gzip
import hashlib
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tempfile


class Digests(HTMLParser):
    def __init__(self):
        super().__init__()
        self.values = {}

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        label = attrs.get("aria-label", "")
        digest = attrs.get("value", "")
        prefix = "Copy to clipboard digest for "
        if tag == "clipboard-copy" and label.startswith(prefix):
            if re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
                self.values[label[len(prefix):]] = digest[7:]


def fetch(url, target):
    subprocess.run([
        "curl", "--fail", "--silent", "--show-error", "--location",
        "--retry", "3", "--connect-timeout", "30", "--max-time", "600",
        "--proto", "=https", "--proto-redir", "=https", "--output", str(target), url,
    ], check=True)


def verify(path, expected):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    if digest.hexdigest() != expected:
        raise RuntimeError("download checksum mismatch")


def github(repo, tag, name, work):
    # Release pages expose the same SHA-256 digests as the API, without the
    # unauthenticated API rate limit common to shared image builders.
    page = work / "assets.html"
    fetch("https://github.com/{}/releases/expanded_assets/{}".format(repo, tag), page)
    digests = Digests()
    digests.feed(page.read_text())
    if name not in digests.values:
        raise RuntimeError("release asset has no published SHA-256: " + name)
    archive = work / name
    fetch("https://github.com/{}/releases/download/{}/{}".format(repo, tag, name), archive)
    verify(archive, digests.values[name])
    return archive


def release_tag(repo):
    url = subprocess.check_output([
        "curl", "-fLsS", "--retry", "3", "--max-time", "60", "-o", "/dev/null",
        "-w", "%{url_effective}", "https://github.com/{}/releases/latest".format(repo),
    ], text=True)
    tag = url.rstrip("/").rsplit("/", 1)[-1]
    if not re.fullmatch(r"v?\d+\.\d+\.\d+", tag):
        raise RuntimeError("cannot resolve stable release tag")
    return tag


def version(value, stable=False):
    if stable and value == "stable":
        return value
    if not re.fullmatch(r"v?\d+\.\d+\.\d+", value):
        raise RuntimeError("expected an exact release version, got " + value)
    return "v" + value.lstrip("v")


def extract(archive, target):
    target.mkdir()
    subprocess.run([
        "tar", "-xzf", str(archive), "-C", str(target),
        "--no-same-owner", "--no-same-permissions",
    ], check=True)


def link(source, name):
    target = Path("/usr/local/bin") / name
    # A feature is explicitly installing these tools; replace a launcher only,
    # never remove a pre-existing directory or recursively delete an installation.
    temporary = target.with_name(".astronvim-" + name)
    if temporary.exists() or temporary.is_symlink():
        temporary.unlink()
    temporary.symlink_to(source)
    os.replace(str(temporary), str(target))


def node_release(requested, work):
    if not re.fullmatch(r"v?\d+(?:\.\d+\.\d+)?", requested):
        raise RuntimeError("nodeVersion must be a major or exact release")
    if int(requested.lstrip("v").split(".")[0]) < 22:
        raise RuntimeError("Node.js 22 or newer is required")
    if "." in requested:
        return version(requested)
    index = work / "node-index.json"
    fetch("https://nodejs.org/dist/index.json", index)
    prefix = "v" + requested.lstrip("v") + "."
    for entry in json.loads(index.read_text()):
        if entry["version"].startswith(prefix):
            return version(entry["version"])
    raise RuntimeError("Node.js major was not found")


def build_tree_sitter(tag, arch, target, work):
    print("Tree-sitter release binary is incompatible; building CLI for the image libc", flush=True)
    # Tree-sitter 0.26 generates QuickJS bindings through libclang/bindgen.
    if shutil.which("apt-get"):
        subprocess.run(["apt-get", "install", "-y", "--no-install-recommends", "libclang-dev"], check=True)
    else:
        subprocess.run(["dnf", "install", "-y", "clang-devel"], check=True)
    triple = ("aarch64" if arch == "arm64" else arch) + "-unknown-linux-gnu"
    url = "https://static.rust-lang.org/rustup/dist/" + triple + "/rustup-init"
    bootstrap = work / "rustup-init"
    checksum = work / "rustup.sha256"
    fetch(url, bootstrap)
    fetch(url + ".sha256", checksum)
    verify(bootstrap, checksum.read_text().split()[0])
    bootstrap.chmod(0o755)
    env = dict(os.environ, RUSTUP_HOME=str(work / "rustup"), CARGO_HOME=str(work / "cargo"))
    env["PATH"] = str(work / "cargo/bin") + ":" + env["PATH"]
    subprocess.run([str(bootstrap), "-y", "--no-modify-path", "--profile", "minimal",
                    "--default-toolchain", "stable"], env=env, check=True)
    subprocess.run([str(work / "cargo/bin/cargo"), "install", "tree-sitter-cli", "--locked",
                    "--git", "https://github.com/tree-sitter/tree-sitter", "--tag", tag,
                    "--root", str(work / "built-tree")], env=env, check=True)
    shutil.copy2(work / "built-tree/bin/tree-sitter", target)


def install(work):
    arch = "arm64" if platform.machine() in ("aarch64", "arm64") else "x86_64"
    nvim = version(os.environ.get("VERSION", "0.11.5"), stable=True)
    if nvim == "stable":
        nvim = release_tag("neovim/neovim")
    if tuple(map(int, nvim[1:].split("."))) < (0, 10, 0):
        raise RuntimeError("AstroNvim requires Neovim >= 0.10")
    name = "nvim-linux-" + arch
    archive = github("neovim/neovim", nvim, name + ".tar.gz", work)
    destination = Path("/opt/astronvim") / ("neovim-" + nvim)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists():
        extract(archive, work / "nvim")
        shutil.move(str(work / "nvim" / name), str(destination))
    link(destination / "bin/nvim", "nvim")

    tree = version(os.environ.get("TREESITTERVERSION", "0.26.1"))
    tree_arch = "x64" if arch == "x86_64" else arch
    tree_path = Path("/opt/astronvim") / ("tree-sitter-" + tree)
    if not tree_path.exists() or subprocess.run([str(tree_path), "--version"], capture_output=True).returncode:
        archive = github("tree-sitter/tree-sitter", tree, "tree-sitter-linux-" + tree_arch + ".gz", work)
        with gzip.open(archive, "rb") as source, tree_path.open("wb") as target:
            shutil.copyfileobj(source, target)
        tree_path.chmod(0o755)
        if subprocess.run([str(tree_path), "--version"], capture_output=True).returncode:
            build_tree_sitter(tree, arch, tree_path, work)
    link(tree_path, "tree-sitter")

    node = node_release(os.environ.get("NODEVERSION", "22"), work)
    node_arch = "x64" if arch == "x86_64" else arch
    name = "node-{}-linux-{}".format(node, node_arch)
    checksums = work / "node-checksums.txt"
    fetch("https://nodejs.org/dist/{}/SHASUMS256.txt".format(node), checksums)
    filename = name + ".tar.gz"
    sums = {line.split()[1]: line.split()[0] for line in checksums.read_text().splitlines()}
    archive = work / filename
    fetch("https://nodejs.org/dist/{}/{}".format(node, filename), archive)
    verify(archive, sums[filename])
    node_path = Path("/opt/astronvim") / name
    if not node_path.exists():
        extract(archive, work / "node")
        shutil.move(str(work / "node" / name), str(node_path))
    for command in ("node", "npm", "npx"):
        link(node_path / "bin" / command, command)

    for repo, executable in (("BurntSushi/ripgrep", "rg"), ("sharkdp/fd", "fd")):
        if shutil.which(executable):
            continue
        tag = release_tag(repo)
        triple = ("x86_64-unknown-linux-musl" if executable == "rg" and arch == "x86_64"
                  else ("aarch64" if arch == "arm64" else arch) + "-unknown-linux-gnu")
        package = "ripgrep" if executable == "rg" else "fd"
        asset_version = tag if executable == "fd" else tag.lstrip("v")
        archive = github(repo, tag, "{}-{}-{}.tar.gz".format(package, asset_version, triple), work)
        extract(archive, work / executable)
        source = next((work / executable).glob("*/" + executable))
        target = Path("/opt/astronvim") / executable
        shutil.copy2(source, target)
        link(target, executable)

    if not shutil.which("lazygit"):
        tag = release_tag("jesseduffield/lazygit")
        name = "lazygit_{}_linux_{}.tar.gz".format(tag.lstrip("v"), arch)
        archive = github("jesseduffield/lazygit", tag, name, work)
        extract(archive, work / "lazygit")
        target = Path("/opt/astronvim/lazygit")
        shutil.copy2(work / "lazygit/lazygit", target)
        link(target, "lazygit")

    if os.environ.get("INSTALLPYTHONTOOLS", "true") == "true":
        venv = Path("/opt/astronvim/python")
        subprocess.run(["python3", "-m", "venv", str(venv)], check=True)
        subprocess.run([str(venv / "bin/pip"), "install", "--no-cache-dir", "--disable-pip-version-check",
                        "pynvim", "black", "isort", "yamllint", "ansible-core", "ansible-lint"], check=True)
        for command in ("black", "isort", "yamllint", "ansible", "ansible-playbook", "ansible-vault", "ansible-lint"):
            link(venv / "bin" / command, command)
        # An external symlink to venv Python loses pyvenv.cfg discovery.
        python_launcher = Path("/usr/local/bin/astronvim-python")
        if python_launcher.is_symlink():
            python_launcher.unlink()
        python_launcher.write_text('#!/bin/sh\nexec /opt/astronvim/python/bin/python "$@"\n')
        python_launcher.chmod(0o755)
        # Set the Python provider for every launch without editing user Lua.
        launcher = Path("/usr/local/bin/nvim")
        launcher.unlink()
        launcher.write_text(
            '#!/bin/sh\nexec "' + str(destination / "bin/nvim") + '" '
            '--cmd "let g:python3_host_prog=\'/usr/local/bin/astronvim-python\'" "$@"\n'
        )
        launcher.chmod(0o755)
    for command in ("nvim", "node", "tree-sitter", "rg", "fd"):
        subprocess.run([command, "--version"], check=True)


if __name__ == "__main__":
    with tempfile.TemporaryDirectory(prefix="astronvim-install-") as folder:
        install(Path(folder))
