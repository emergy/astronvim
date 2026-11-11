# Дополнение Dev Containers CLI в Bash

Команды, вложенные подкоманды, параметры и допустимые значения берутся из
установленного `devcontainer` через его `--get-yargs-completions`. Список
подкоманд не хранится вручную и следует за обновлениями CLI.

Примеры ввода с последующим нажатием Tab:

```text
devcontainer u
devcontainer features pa
devcontainer up --wo
devcontainer up --log-level d
devcontainer up --workspace-folder project
devcontainer up --config=config
```

Для `--workspace-folder` и `--user-data-folder` предлагаются локальные каталоги;
для `--config`, `--override-config`, `--secrets-file` — локальные файлы.
Поддерживаются пробелы в именах и формы `--параметр значение` / `--параметр=значение`.

Исходник: `completions/devcontainer.bash`. В текущем WSL установленная ссылка
`~/.local/share/bash-completion/completions/devcontainer` указывает на него.
Bash-completion загружает дополнение при первом запросе; `.bashrc` не изменён.
Нужны Bash, bash-completion и работающий Dev Containers CLI вместе с Node.js
в PATH интерактивной оболочки. Zsh и другие устройства этой настройкой пока
не охвачены.

На другом устройстве с Bash можно создать такую же ссылку в
`${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions/devcontainer`,
если там ещё нет пользовательского дополнения. Для принудительной загрузки
в текущую оболочку:

```bash
source ~/.config/nvim/completions/devcontainer.bash
```

Проверка с установленным CLI:

```bash
bash -n completions/devcontainer.bash
bash tests/check_devcontainer_completion.bash
```

Тест проверяет команды и параметры, перечисляемые значения, вложенные
подкоманды, `=`, каталоги и файлы с пробелами. Вызов Docker перехвачен
тестовой программой; тест требует, чтобы он не происходил. Проверено в WSL
с Dev Containers CLI 0.90.0. Журнал установки:
`.operation-manifests/devcontainer-completion.json`.
