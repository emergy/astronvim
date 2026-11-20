# Neovim с конфигурацией emergy/astronvim

Feature устанавливает Neovim, зависимости и конфиг из того же Git-коммита,
из которого CI собрал OCI-пакет. URL конфига и Git credentials не нужны.

```json
"features": {
  "ghcr.io/emergy/astronvim/astronvim:1": {
    "version": "0.11.5"
  }
}
```

Для настроек по умолчанию достаточно `{}`. Пользователь контейнера должен
существовать в образе или создаваться другой feature, например `common-utils`.

| Параметр | По умолчанию | Назначение |
| --- | --- | --- |
| `version` | `0.11.5` | Точная версия Neovim с необязательным `v` или `stable`. |
| `nodeVersion` | `22` | Основная или точная версия Node.js, не ниже 22. |
| `treeSitterVersion` | `0.26.1` | Точная версия Tree-sitter CLI. |
| `installPythonTools` | `true` | Отдельный venv: pynvim, black/isort/yamllint, ansible-core/ansible-lint и ansible-vault. |
| `installPlugins` | `true` | Lazy restore при первом создании контейнера. |

При сборке от root ставятся C/C++, make/cmake, Git/SSH/curl/tar/unzip,
ripgrep/fd, lazygit, tmux, Node и выбранный Neovim. Опубликованные SHA-256
бинарников проверяются. Инструменты находятся в `/opt/astronvim` и `/usr/local/bin`.
Конфиг распаковывается в `/usr/local/share/astronvim/config`.

`onCreateCommand` запускает `astronvim-setup` от remote user. Конфиг копируется
в `$XDG_CONFIG_HOME/nvim`, обычно `~/.config/nvim`, без Git metadata. Каталоги
cache/data/state создаёт тот же пользователь. Пустой каталог, включая volume,
поддерживается; непустой посторонний конфиг не перезаписывается.

Повторный запуск сохраняет локальные правки. Если HOME пережил пересоздание
контейнера, новый коммит внутри образа не заменяет старую пользовательскую копию:
установщик сообщает оба SHA. Для нового снимка используй новый config/state
либо явно сохрани и перенеси старые `~/.config/nvim` и
`~/.local/share/astronvim-feature`.

Lazy restore учитывает bundled `lazy-lock.json` и ждёт установки Mason.
`installPlugins: false` оставляет плагины обычному первому запуску Neovim.
Роли/коллекции Ansible не устанавливаются, `ansible-galaxy` не запускается.
Авторизация Copilot/Codex выполняется пользователем отдельно.

Платформы: Linux glibc amd64/arm64, Debian/Ubuntu (apt) и EL9/EL10 (dnf).
Alpine/musl не поддерживается. Несовместимый с glibc бинарник Tree-sitter
заменяется сборкой той же версии из исходников с временным Rust и libclang.
Nerd Font нужен на клиенте терминала. Clipboard зависит от UI/display: xclip
в apt-образах не создаёт X display; при поддержке транспорта доступен OSC52.
AstroNvim major остаётся заданным Lua-конфигом, автоматической миграции 5 → 6 нет.

CI и публикация описаны в `docs/devcontainer-feature.md` исходного репозитория.
