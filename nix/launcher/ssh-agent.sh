# shellcheck shell=bash
# Общий агент для сессий Launcher; рабочий forwarded agent сохраняется.
__workstation_agent_status() {
  ssh-add -l >/dev/null 2>&1
  case $? in 0|1) return 0 ;; *) return 1 ;; esac
}
__workstation_agent_setup() {
  command -v ssh-agent >/dev/null 2>&1 || return 0
  # Не добавляем локальные ключи в уже переданный через SSH агент.
  if __workstation_agent_status; then return 0; fi
  if ! __workstation_agent_status; then
    local directory="${TMPDIR:-/tmp}/nix-launcher-ssh-${UID}"
    (umask 077; mkdir -p "$directory") || return 1
    [[ -O $directory && ! -L $directory ]] || return 1
    export SSH_AUTH_SOCK="$directory/agent.sock"
    (
      flock -x 9 || exit 1
      if [[ -r $directory/current ]]; then
        IFS= read -r SSH_AUTH_SOCK < "$directory/current"
        export SSH_AUTH_SOCK
      fi
      if ! __workstation_agent_status; then
        # Новый адрес вместо удаления потенциально чужого/stale socket.
        local socket="$directory/agent-${BASHPID}.sock"
        (umask 077; ssh-agent -a "$socket" -s > /dev/null 9>&-) || exit 1
        printf '%s\n' "$socket" > "$directory/current"
      fi
    ) 9>"$directory/lock"
    if [[ -r $directory/current ]]; then
      IFS= read -r SSH_AUTH_SOCK < "$directory/current"
      export SSH_AUTH_SOCK
    fi
  fi
  # Защищённые паролем ключи можно добавить вручную через ssh-add.
  # Новые оболочки не вызывают повторных запросов пароля.
  local status key header
  ssh-add -l >/dev/null 2>&1; status=$?
  [[ $status == 1 ]] || return 0
  for key in "$HOME"/.ssh/*; do
    [[ -f $key ]] || continue
    IFS= read -r header < "$key" || continue
    case $header in
      '-----BEGIN '*'PRIVATE KEY-----')
        SSH_ASKPASS_REQUIRE=force SSH_ASKPASS="$(command -v false)" \
          ssh-add -q "$key" </dev/null >/dev/null 2>&1 || : ;;
    esac
  done
}
__workstation_agent_setup
unset -f __workstation_agent_setup __workstation_agent_status
