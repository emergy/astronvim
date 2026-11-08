# shellcheck shell=bash
# Создаёт только отсутствующие ссылки, существующее содержимое не меняет.
set -eu
shared=/sdcard
[ -r "$shared" ] && [ -x "$shared" ] || {
  echo 'Нет доступа к общей памяти Android. Разрешите доступ к файлам для Launcher.' >&2
  exit 1
}
mkdir -p "$HOME/storage"
for entry in shared: downloads:Download dcim:DCIM pictures:Pictures music:Music movies:Movies documents:Documents; do
  name=${entry%%:*}
  directory=${entry#*:}
  destination="$shared${directory:+/$directory}"
  [ -d "$destination" ] || continue
  if [ ! -e "$HOME/storage/$name" ] && [ ! -L "$HOME/storage/$name" ]; then
    ln -s "$destination" "$HOME/storage/$name"
    printf '%s -> %s\n' "$HOME/storage/$name" "$destination"
  fi
done
