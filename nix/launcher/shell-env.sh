# Общая среда для интерактивного shell и команд через SSH.
if [ -z "${__NOD_SESS_INIT_SOURCED:-}" ] && [ -r /etc/profile ]; then
  . /etc/profile
fi
case "${PATH:-}" in
  "$HOME/.local/share/workstation/current/bin:$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/share/workstation/current/bin:$HOME/.local/bin:${PATH:-}" ;;
esac
export NVIM_PROFILE=nix-on-droid
export EDITOR=nvim VISUAL=nvim
export LANG=C.UTF-8
export TMPDIR=/tmp
