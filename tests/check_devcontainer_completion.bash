#!/usr/bin/env bash
# Проверка установленного CLI: вызывается только его механизм дополнения.
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
. /usr/share/bash-completion/bash_completion
. "$root/completions/devcontainer.bash"
mkdir -p "$root/.tmp"
work=$(mktemp -d "$root/.tmp/devcontainer-completion-XXXXXX")
mkdir -p "$work/project space" "$work/project-other" "$work/bin"
printf '{}\n' > "$work/config space.json"
printf text > "$work/not-folder.txt"
printf '#!/bin/sh\nprintf called > "%s/docker-called"\nexit 99\n' "$work" > "$work/bin/docker"
chmod +x "$work/bin/docker"
export PATH="$work/bin:$PATH"
cd "$work"
complete_line() {
  COMP_LINE=$1
  shift
  COMP_WORDS=("$@")
  COMP_CWORD=$((${#COMP_WORDS[@]}-1))
  COMP_POINT=${#COMP_LINE}
  _devcontainer_completion
}
contains() {
  local item
  for item in "${COMPREPLY[@]}"; do [[ $item != "$1" ]] || return 0; done
  printf 'Missing completion: %s; got: %s\n' "$1" "${COMPREPLY[*]}" >&2
  return 1
}
complete_line 'devcontainer u' devcontainer u
contains up || exit 1
contains upgrade || exit 1
complete_line 'devcontainer features pa' devcontainer features pa
contains package || exit 1
complete_line 'devcontainer up --wo' devcontainer up --wo
contains --workspace-folder || exit 1
contains --workspace-mount-consistency || exit 1
complete_line 'devcontainer up --log-level d' devcontainer up --log-level d
contains debug || exit 1
complete_line 'devcontainer up --log-level=tr' devcontainer up --log-level = tr
contains trace || exit 1
complete_line 'devcontainer up --workspace-folder project' devcontainer up --workspace-folder project
contains 'project space' || exit 1
contains 'project-other' || exit 1
complete_line 'devcontainer up --config config' devcontainer up --config config
contains 'config space.json' || exit 1
complete_line 'devcontainer up --config=config' devcontainer up --config = config
contains 'config space.json' || exit 1
[[ ! -e $work/docker-called ]] || exit 1
printf 'PASS: native commands, subcommands, flags, values, equals syntax, directories/files with spaces; Docker not called\n'
