#!/usr/bin/env sh
# Явная установка инструментов в НОВЫЙ каталог данных тестовой/рабочей сборки.
set -eu

case "${PREFIX:-}" in
  */com.termux/*) ;;
  *) echo 'Этот скрипт предназначен для Termux.' >&2; exit 1 ;;
esac

if [ "$#" -ne 1 ]; then
  echo 'Использование: sh scripts/prepare_termux_tools.sh /новый/каталог/nvim/tools' >&2
  exit 1
fi

destination=$1
node -e 'if (Number(process.versions.node.split(".")[0]) < 26) { console.error("Требуется Node.js 26 или новее"); process.exit(1); }'
if [ -e "$destination" ]; then
  echo "Каталог уже существует; автоматическая перезапись запрещена: $destination" >&2
  exit 1
fi
repository=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d "${TMPDIR:?}/nvim-tools.XXXXXX")
mkdir -p "$destination/bin" "$work/native" "$work/lists/partial" "$work/apt-cache/archives/partial"
cp "$repository/tools/package.json" "$repository/tools/package-lock.json" "$destination/"

npm ci --ignore-scripts --no-audit --no-fund --prefix "$destination" --cache "$work/npm" >"$work/npm.log" 2>&1
(
  cd "$work"
  # Обновляем только изолированный индекс: системные списки и пакеты не меняются.
  apt-get -o "Dir::State::lists=$work/lists" -o "Dir::Cache=$work/apt-cache" update >"$work/native-index.log" 2>&1
  apt-get -o "Dir::State::lists=$work/lists" -o "Dir::Cache=$work/apt-cache" download codex helm-ls >"$work/native-download.log" 2>&1
  for package in ./*.deb; do dpkg-deb -x "$package" "$work/native"; done
)
cp -a "$work/native$PREFIX/bin/." "$destination/bin/"
"$destination/bin/codex" --version
printf 'Инструменты: %s\nЖурналы: %s\n' "$destination" "$work"
