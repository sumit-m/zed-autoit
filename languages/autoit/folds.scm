; AutoIt foldable regions.
;
; NOTE (as of May 2026): Zed does not yet honor folds.scm. The file is
; kept here as future-proofing: tracked in zed-industries/zed#22703, and
; this content will start taking effect automatically once Zed ships the
; feature. Today, Zed folds via two other mechanisms:
;   1. Multi-line LEAF tokens (block_comment qualifies).
;   2. Indent-range detection (function bodies, if/while/for/switch
;      bodies — anything whose body is indented one level deeper).
; Constructs that match neither (notably region_block, since AutoIt
; convention puts region bodies at the same indent as #region/#endregion)
; can't fold today.
;
; Single-line forms (if_inline_statement) and one-line directives are
; intentionally absent below — no body to collapse.

; Function bodies and all multi-line control-flow blocks.
(function_declaration) @fold

(if_statement) @fold
(elseif_clause) @fold
(else_clause)   @fold

(while_statement) @fold
(do_statement)    @fold

(for_to_statement) @fold
(for_in_statement) @fold

(switch_statement) @fold
(switch_case)      @fold
(select_statement) @fold
(select_case)      @fold

(with_statement) @fold

; #region … #endregion blocks (the reason this file exists).
(region_block) @fold

; Multi-line block comments (#cs … #ce, #comments-start … #comments-end).
(block_comment) @fold
