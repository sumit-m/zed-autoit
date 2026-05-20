; Each block construct indents its body one level. Zed reads the indent
; queries to size the auto-indent step after Enter and to know where to
; dedent on the closing keyword. Single-line if_inline_statement is
; intentionally absent — there's no body to indent.

(function_declaration) @indent

(if_statement) @indent
(elseif_clause) @indent
(else_clause)   @indent

(while_statement) @indent
(do_statement)    @indent

(for_to_statement) @indent
(for_in_statement) @indent

(switch_statement) @indent
(switch_case)      @indent
(select_statement) @indent
(select_case)      @indent

(with_statement) @indent
