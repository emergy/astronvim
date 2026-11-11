" Загружается внутри :syntax include, чтобы язык и Jinja имели одну область.
execute 'runtime! syntax/' . b:yaml_block_syntax . '.vim'
if &l:filetype ==# 'yaml.jinja2' || &l:filetype ==# 'yaml.ansible'
  runtime! syntax/jinja2.vim
endif
