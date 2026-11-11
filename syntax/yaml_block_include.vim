" Совместимость с обработчиком, уже загруженным до обновления конфигурации.
let b:embedded_block_syntax = b:yaml_block_syntax
try
  runtime! syntax/embedded_block_include.vim
finally
  unlet! b:embedded_block_syntax
endtry
