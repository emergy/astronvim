# Dev Container Feature: CI и GHCR

GitHub Actions собирает feature `ghcr.io/emergy/astronvim/astronvim:1`.
Это OCI Feature для `devcontainer.json`, а не самостоятельный образ контейнера.
В пакет включён снимок нашего конфига; выбранный Neovim устанавливается при
сборке контейнера. Клонировать Git при создании пользовательского конфига не нужно.

```json
{
  "image": "ubuntu:24.04",
  "remoteUser": "developer",
  "features": {
    "ghcr.io/emergy/astronvim/astronvim:1": {}
  }
}
```

Пользователь должен существовать в образе или создаваться через `common-utils`.
Параметры — в [README feature](../devcontainer/features/astronvim/README.md).
Внешний dotfiles installer не должен одновременно менять тот же `~/.config/nvim`.

## Публикация

Workflow `.github/workflows/devcontainer-feature.yml` запускает тесты при push
в `v5`/`feat/devcontainer-feature` и PR в `v5`. Только успешный push в `v5`
исходного `emergy/astronvim` публикует пакет; PR и feature-ветка его не публикуют.
Просмотр и повторный запуск — на странице [Actions](https://github.com/emergy/astronvim/actions).

Версия feature — `1.0.${GITHUB_RUN_NUMBER}`. Каждый новый run получает новый
patch-тег; повтор run сохраняет его версию. Dev Containers CLI обновляет
плавающие major/minor теги. `:1` выбирает текущую первую основную версию,
`:1.0.N` фиксирует конкретный снимок. Параметр `version` выбирает Neovim независимо
от версии самого пакета.

Используется штатный `GITHUB_TOKEN`: отдельный PAT в secrets не нужен.
У workflow `contents: read`, а только у publish job — `packages: write`.
Actions закреплены по SHA, Dev Containers CLI — на `0.90.0`.
Git-теги и документация автоматически не переписываются.

GHCR может создать первый пакет приватным. Для установки без авторизации
поставь visibility `Public` в настройках пакета на
[GitHub Packages](https://github.com/emergy?tab=packages).
До этого потребителю нужны credentials с доступом к пакету.

Если рабочая конфигурация переедет из `v5` в другую ветку, обнови triggers и
условие publish job. Ветка `main` этим workflow не меняется.

## Содержимое снимка

`scripts/package_devcontainer_feature.py` читает точный Git-коммит через Git
objects, не рабочие файлы. Незакоммиченные правки и untracked исключены.
`config-source.json` содержит SHA коммита и контрольные суммы файлов.
Порядок, режимы и временные метки tar/gzip зафиксированы для воспроизводимости.

Включаются `init.lua`, `lazy-lock.json`, настройки редактора и runtime-каталоги
`lua`, `after`, `queries`, `snippets`, `syntax`, `colors`, `ftplugin`, `ftdetect`,
`lsp`, `spell`, `scripts`, `terminal`, `tmux`, если они есть в коммите.
Сам упаковщик исключён. Git metadata, CI, тесты, документация и секреты окружения
не входят. Отслеживаемые Git symlinks отклоняются. `tmux/tmux.conf` включён в
снимок, но пользовательский `~/.tmux.conf` автоматически не заменяется.

Существующий пользовательский конфиг сохраняется, даже если новый образ содержит
другой SHA. Для применения нового снимка сохрани старые config/state и создай
их заново. Подробности и параметры установки — в README feature.

## Проверки

CI строит Ubuntu 24.04 amd64/arm64 и CentOS Stream 10 amd64, запускает lifecycle
от обычного пользователя, проверяет повторный setup, пользовательскую правку,
доступность кэша и инструментов. В smoke-тестах `installPlugins=false`, Neovim
запускается с `-u NONE -i NONE`: Lazy/Mason/парсеры не устанавливаются побочно.
Это не проверка UI, русской раскладки или мобильной клавиатуры.

Локально в отдельном checkout:

```sh
python3 -m unittest discover -s tests/devcontainer_feature -v
bash -n devcontainer/features/astronvim/install.sh
python3 scripts/package_devcontainer_feature.py \
  --version 1.0.1 --output .tmp/feature-src
docker build -f tests/devcontainer_feature/Dockerfile \
  --build-arg BASE_IMAGE=ubuntu:24.04 \
  -t astronvim-feature-test .tmp/feature-src/astronvim
docker run --rm astronvim-feature-test
```

Output должен быть новым: упаковщик не удаляет предыдущие артефакты.
Проверять полную установку плагинов можно отдельно в одноразовом контейнере с
явно включённым `installPlugins`, не на рабочем HOME.

Источники: [Features](https://containers.dev/implementors/features/),
[публикация](https://github.com/devcontainers/action),
[AstroNvim 5](https://raw.githubusercontent.com/AstroNvim/docs/v5/src/content/docs/index.mdx),
[AstroNvim 6](https://docs.astronvim.com/).
