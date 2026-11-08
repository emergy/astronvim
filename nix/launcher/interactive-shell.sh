# shellcheck shell=bash
# Интерактивная среда Nix Launcher; пути Android/Termux сюда не подставляются.
alias vim=nvim
alias bashrc='nvim "$HOME/.bashrc" && . "$HOME/.bashrc"'
alias sshc='nvim "$HOME/.ssh/config"'
alias gg=lazygit
alias s='invi --config "$HOME/.config/invi/config.js"'
alias ll='ls -l'
alias la='ls -la'
alias lt='ls -lrt'
alias k=kubectl
alias a='ssh adm-ng'
alias keys='nvim "$HOME/.termux/keyboard/layout.xml" && termux-reload-settings'
alias hsyncto='rclone sync --dry-run -P --links --exclude "/storage" --exclude "/storage/**" "$HOME/" dropbox:nix-launcher-home/'
alias hsyncfrom='rclone sync --dry-run -P --links --exclude "/storage" --exclude "/storage/**" dropbox:nix-launcher-home/ "$HOME/"'

# Дата вычисляется при запуске; ошибка tar не скрывается успешным rclone.
tbackup-home() (
  set -o pipefail
  tar --exclude='./.ssh/*.sock' -czpC "$HOME" . |
    rclone rcat "dropbox:nix-launcher-backup/home-$(date +%Y%m%d%H%M%S).tar.gz"
)
tbackup-root() (
  set -o pipefail
  # Сохраняем воспроизводимые декларации вместо гигантского /nix/store.
  tar -czpC "$HOME" .config/nix-on-droid .config/workstation \
    .bashrc .bash_profile .termux |
    rclone rcat "dropbox:nix-launcher-backup/root-$(date +%Y%m%d%H%M%S).tar.gz"
)

export KUBE_EDITOR=nvim
if [[ -z ${KUBECONFIG:-} ]]; then
  __workstation_kubeconfigs=()
  [[ ! -f $HOME/.kube/config ]] || __workstation_kubeconfigs+=("$HOME/.kube/config")
  for __workstation_config in "$HOME"/.kube/*.config; do
    [[ ! -f $__workstation_config ]] || __workstation_kubeconfigs+=("$__workstation_config")
  done
  if ((${#__workstation_kubeconfigs[@]})); then
    KUBECONFIG=$(IFS=:; printf '%s' "${__workstation_kubeconfigs[*]}")
    export KUBECONFIG
  fi
  unset __workstation_kubeconfigs __workstation_config
fi

__workstation_profile="$HOME/.local/share/workstation/current"
if [[ -r $__workstation_profile/share/bash-completion/bash_completion ]]; then
  . "$__workstation_profile/share/bash-completion/bash_completion"
fi
for __workstation_command in kubectl helm argocd codex; do
  if command -v "$__workstation_command" >/dev/null 2>&1; then
    # shellcheck disable=SC1090
    . <("$__workstation_command" completion bash)
  fi
done
if declare -F __start_kubectl >/dev/null; then
  complete -o default -F __start_kubectl k
fi
if [[ -r $__workstation_profile/share/git/contrib/completion/git-prompt.sh ]]; then
  . "$__workstation_profile/share/git/contrib/completion/git-prompt.sh"
  # Только ветка/состояние операции: без сканирования неотслеживаемых файлов.
  PS1='\u@\h:\w$(__git_ps1 " (%s)")\$ '
else
  PS1='\u@\h:\w\$ '
fi
unset __workstation_profile __workstation_command
. "$HOME/.config/workstation/ssh-agent.sh"

# Обновление DNS при запуске оболочки и вручную; фонового процесса нет.
dns-sync() {
  android-dns --output "$HOME/.local/state/android-dns/resolv.conf"
}
if command -v android-dns >/dev/null 2>&1; then dns-sync; fi
