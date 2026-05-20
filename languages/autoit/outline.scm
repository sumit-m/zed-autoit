; Outline surfaces functions and named regions. Each named #region creates
; an outline entry; unnamed #region directives don't (no useful label).
; Zed displays the outline as a flat list — paired and orphan regions
; both surface, since the grammar emits region_block for paired and
; region_directive for orphan.

; Function definitions
(function_declaration
  (keyword_func) @context
  name: (identifier) @name) @item

; Named paired regions (#region foo … #endregion)
(region_block
  (keyword_region) @context
  name: (directive_args) @name) @item

; Named orphan #region directives (no matching #endregion)
(region_directive
  (keyword_region) @context
  name: (directive_args) @name) @item
