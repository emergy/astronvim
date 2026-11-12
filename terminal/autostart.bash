# Подключается из .bashrc; только новая интерактивная сессия приложения.
case $- in
  *i*) ;;
  *) return 0 ;;
esac
[[ -t 0 && -t 1 ]] || return 0
[[ ${NTERM_AUTOSTART:-1} != 0 ]] || return 0
[[ -z ${NTERM_ACTIVE:-}${NTERM_AUTOSTART_SEEN:-}${NTERM_TOKEN:-}${__nterm_token:-} ]] || return 0
[[ -z ${NVIM:-}${TMUX:-}${STY:-}${SSH_CONNECTION:-}${SSH_CLIENT:-}${SSH_TTY:-} ]] || return 0
command -v nterm >/dev/null 2>&1 || return 0

# Маркер наследуют дочерние оболочки, но не новые сессии приложения.
export NTERM_AUTOSTART_SEEN=1
if ! nterm; then
  printf 'nterm завершился с ошибкой; доступна обычная оболочка Bash.\n' >&2
fi
# Без exec: после выхода остаётся обычный Bash, повторного запуска нет.
return 0
