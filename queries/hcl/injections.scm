((comment) @injection.content
  (#set! injection.language "comment"))

; Явный /* yaml */ перед heredoc важнее языка, указанного именем маркера.
((heredoc_template) @injection.content
  (#hcl-block-language! @injection.content)
  (#set! injection.include-children))
