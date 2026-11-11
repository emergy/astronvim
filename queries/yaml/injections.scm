; Штатные правила: nvim-treesitter/queries/yaml/injections.scm из версии lazy-lock.json.
; Явная метка языка важнее имени YAML-ключа.
((comment) @injection.content
  (#set! injection.language "comment"))

; Github actions ("run") / Gitlab CI ("scripts")
; Taskfile scripts ("cmds", "cmd", "sh")
(block_mapping_pair
  key: (flow_node) @_run
  (#any-of? @_run "run" "script" "before_script" "after_script" "cmds" "cmd" "sh")
  value: (flow_node
    (plain_scalar
      (string_scalar) @injection.content)
    (#set! injection.language "bash")))

(block_mapping_pair
  key: (flow_node) @_run
  (#any-of? @_run "run" "script" "before_script" "after_script" "cmds" "cmd" "sh")
  value: (block_node
    (block_scalar) @injection.content
    (#not-lua-match? @injection.content "^[|>][%d%+%-]*[ \t]+#[ \t]*[%w_%-]+[ \t]*[\r\n]")
    (#set! injection.language "bash")
    (#offset! @injection.content 0 1 0 0)))

(block_mapping_pair
  key: (flow_node) @_run
  (#any-of? @_run "run" "script" "before_script" "after_script" "cmds" "sh")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (flow_node
          (plain_scalar
            (string_scalar) @injection.content))
        (#set! injection.language "bash")))))

(block_mapping_pair
  key: (flow_node) @_run
  (#any-of? @_run "script" "before_script" "after_script" "cmds" "sh")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (block_node
          (block_scalar) @injection.content
          (#not-lua-match? @injection.content "^[|>][%d%+%-]*[ \t]+#[ \t]*[%w_%-]+[ \t]*[\r\n]")
          (#set! injection.language "bash")
          (#offset! @injection.content 0 1 0 0))))))

; Prometheus Alertmanager ("expr")
(block_mapping_pair
  key: (flow_node) @_expr
  (#eq? @_expr "expr")
  value: (flow_node
    (plain_scalar
      (string_scalar) @injection.content)
    (#set! injection.language "promql")))

(block_mapping_pair
  key: (flow_node) @_expr
  (#eq? @_expr "expr")
  value: (block_node
    (block_scalar) @injection.content
    (#not-lua-match? @injection.content "^[|>][%d%+%-]*[ \t]+#[ \t]*[%w_%-]+[ \t]*[\r\n]")
    (#set! injection.language "promql")
    (#offset! @injection.content 0 1 0 0)))

(block_mapping_pair
  key: (flow_node) @_expr
  (#eq? @_expr "expr")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (flow_node
          (plain_scalar
            (string_scalar) @injection.content))
        (#set! injection.language "promql")))))

(block_mapping_pair
  key: (flow_node) @_expr
  (#eq? @_expr "expr")
  value: (block_node
    (block_sequence
      (block_sequence_item
        (block_node
          (block_scalar) @injection.content
          (#not-lua-match? @injection.content "^[|>][%d%+%-]*[ \t]+#[ \t]*[%w_%-]+[ \t]*[\r\n]")
          (#set! injection.language "promql")
          (#offset! @injection.content 0 1 0 0))))))

; Язык указан в комментарии заголовка, например | # sh или >- # py.
((block_scalar
   (comment) @injection.language) @injection.content
  (#lua-match? @injection.language "^#[ \t]*[%a][%w_%-]*[ \t]*$")
  (#lua-match? @injection.content "\n")
  (#gsub! @injection.language "^#[ \t]*([%w_%-]+)[ \t]*$" "%1")
  (#gsub! @injection.language "^sh$" "bash")
  (#gsub! @injection.language "^py$" "python")
  (#gsub! @injection.language "^js$" "javascript")
  (#gsub! @injection.language "^ts$" "typescript")
  (#yaml-block-body! @injection.content)
  (#set! injection.include-children))
