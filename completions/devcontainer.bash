# shellcheck shell=bash
# Список команд, параметров и значений предоставляет установленный Dev Containers CLI.
_devcontainer_completion() {
  local cur prev cword candidate
  local -a words
  COMPREPLY=()
  if declare -F _get_comp_words_by_ref >/dev/null; then
    _get_comp_words_by_ref -n = cur prev words cword || return 0
  else
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
    cur=${words[cword]}
    prev=${words[cword-1]:-}
  fi

  local -a args=("${words[@]:0:cword+1}")
  if [[ $cur == --*=* ]]; then
    prev=${cur%%=*}
    cur=${cur#*=}
    args=("${words[@]:0:cword}" "$prev" "$cur")
  fi
  case "$prev" in
    --workspace-folder|--user-data-folder)
      if declare -F _filedir >/dev/null; then _filedir -d || :; fi
      return
      ;;
    --config|--override-config|--secrets-file)
      if declare -F _filedir >/dev/null; then _filedir || :; fi
      return
      ;;
  esac

  local candidates
  if ! candidates=$(command devcontainer --get-yargs-completions "${args[@]}" 2>/dev/null); then return 0; fi
  while IFS= read -r candidate; do
    [[ -n $candidate && $candidate == "$cur"* ]] && COMPREPLY+=("$candidate")
  done <<< "$candidates"
  return 0
}

complete -o default -F _devcontainer_completion devcontainer
