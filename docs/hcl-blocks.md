# Вложенная подсветка в HCL heredoc

Имя языка указывается в комментарии перед heredoc:

```hcl
variable "network" {
  default = /* yaml */ <<-EOT
- vlan: 358
  dhcp4-overrides:
    send-hostname: false
  nameservers:
    - 192.0.2.2
EOT
}
```

Поддерживаются `<<EOT` и `<<-EOT`, произвольные имена завершающего маркера,
обычный HCL, Terraform и `hcl.jinja2`. Подсветка заканчивается на строке
завершающего маркера. Внутри HCL + Jinja сохраняется подсветка Jinja.

После `<<-EOT` комментарий ставить нельзя: HCL требует сразу перевод строки.
Вариант `default = <<-EOT # yaml` невалиден для Packer/Terraform.
Выбранную форму `default = /* yaml */ <<-EOT` проверили через `packer fmt -`:
форматтер принимает её и сохраняет комментарий на месте.

Также поддерживается язык в имени самого маркера:

```hcl
default = <<-YAML
name: example
YAML
```

Комментарий имеет приоритет: `/* json */ <<-YAML` выбирает JSON.
Алиасы языков совпадают с [YAML-блоками](yaml-blocks.md): `sh`/`bash`,
`py`/`python`, `js`/`javascript`, `ts`/`typescript`. Можно указать другое
доступное имя языка. Неизвестная метка оставляет обычную HCL-подсветку.
Добавление, изменение и удаление комментария применяются при редактировании.

В обычном HCL с активным Tree-sitter используется дочерний парсер. Для Vim
syntax и HCL + Jinja подключается встроенный syntax выбранного языка.
Автоматической установки парсеров и плагинов нет.

Настройки: `lua/embedded_blocks.lua`, `after/syntax/hcl.lua`,
`after/syntax/terraform.lua`, `queries/hcl/injections.scm`,
`syntax/embedded_block_include.vim`.

```sh
nvim --headless -u NONE -i NONE -l tests/check_hcl_blocks.lua
```

Тест проверяет YAML/shell/Python/JSON, обе формы heredoc, приоритет комментария,
Jinja, границы, реальные дочерние парсеры и редактирование метки. Для нативной
части нужен установленный парсер HCL или диалекта Terraform той же грамматики.
