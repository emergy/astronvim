#!/usr/bin/env bash
set -euo pipefail

if [[ $(id -u) != 0 ]]; then
  echo 'This feature must be installed as root during the image build.' >&2
  exit 1
fi

case $(uname -m) in
  x86_64 | aarch64 | arm64) ;;
  *) echo 'Supported architectures: Linux x86_64 and arm64.' >&2; exit 1 ;;
esac
# Official Neovim/Node release archives require glibc. Do not silently install
# incompatible glibc binaries on Alpine or otherwise replace an existing libc.
if [[ -f /etc/alpine-release ]]; then
  echo 'Alpine/musl is not supported; use a Debian, Ubuntu, or EL9/EL10 image.' >&2
  exit 1
fi

if command -v apt-get >/dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends \
    ca-certificates curl git openssh-client tar gzip xz-utils unzip \
    python3 python3-venv python3-pip gcc g++ make cmake pkg-config libssl-dev \
    ripgrep fd-find tmux xclip
  if ! command -v fd >/dev/null && command -v fdfind >/dev/null; then
    ln -s "$(command -v fdfind)" /usr/local/bin/fd
  fi
elif command -v dnf >/dev/null; then
  dnf install -y --setopt=install_weak_deps=False \
    ca-certificates curl-minimal git openssh-clients tar gzip xz unzip \
    python3 python3-pip gcc gcc-c++ make cmake pkgconf-pkg-config openssl-devel tmux
  # EL repositories do not consistently provide ripgrep or fd; the verified
  # upstream binaries below provide the same tools without enabling EPEL.
else
  echo 'Supported package managers: apt-get and dnf (glibc Linux).' >&2
  exit 1
fi

feature_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
python3 "$feature_dir/install-tools.py"
install -d -m 0755 /usr/local/share/astronvim
install -m 0755 "$feature_dir/setup.py" /usr/local/share/astronvim/setup.py
install -m 0644 "$feature_dir/plugins.py" /usr/local/share/astronvim/plugins.py
if [[ ! -f "$feature_dir/config.tar.gz" || ! -f "$feature_dir/config-source.json" ]]; then
  echo 'Missing bundled configuration. Run scripts/package_devcontainer_feature.py first.' >&2
  exit 1
fi
install -d -m 0755 /usr/local/share/astronvim/config
tar -xzf "$feature_dir/config.tar.gz" -C /usr/local/share/astronvim/config --no-same-owner
install -m 0644 "$feature_dir/config-source.json" /usr/local/share/astronvim/config-source.json
python3 -c 'import json, os; from pathlib import Path; Path("/usr/local/share/astronvim/settings.json").write_text(json.dumps({"plugins": os.environ.get("INSTALLPLUGINS", "true") == "true"}) + "\n")'
cat > /usr/local/bin/astronvim-setup <<'SH'
#!/bin/sh
exec python3 /usr/local/share/astronvim/setup.py "$@"
SH
chmod 0755 /usr/local/bin/astronvim-setup
echo 'Neovim and bundled config installed; user setup runs on container creation.'
