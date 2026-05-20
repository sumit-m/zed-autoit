; AutoIt v3 highlights — Phase 2g.
; Covers everything the grammar emits as of Phase 2f. Capture names follow
; the standard tree-sitter conventions Zed themes expect.

; --- Comments ---------------------------------------------------------------

(line_comment)  @comment
(block_comment) @comment

; --- Literals ---------------------------------------------------------------

(string) @string
(number) @number

; --- Variables and macros ---------------------------------------------------

; Variables are partitioned by name shape so each (variable) node gets
; exactly one capture:
;   $ALL_CAPS_SNAKE → @constant      (AutoIt convention for constants)
;   anything else   → @variable
((variable) @constant
  (#match? @constant "^\\$[A-Z][A-Z0-9_]*$"))

((variable) @variable
  (#not-match? @variable "^\\$[A-Z][A-Z0-9_]*$"))

(macro) @constant.builtin

(parameter
  name: (variable) @variable.parameter)

; --- Keywords ---------------------------------------------------------------

; Function shape
(keyword_func)    @keyword.function
(keyword_endfunc) @keyword.function
(keyword_volatile) @keyword

; Control flow
(keyword_if)             @keyword.control
(keyword_then)           @keyword.control
(keyword_elseif)         @keyword.control
(keyword_else)           @keyword.control
(keyword_endif)          @keyword.control
(keyword_while)          @keyword.control
(keyword_wend)           @keyword.control
(keyword_do)             @keyword.control
(keyword_until)          @keyword.control
(keyword_for)            @keyword.control
(keyword_to)             @keyword.control
(keyword_step)           @keyword.control
(keyword_next)           @keyword.control
(keyword_in)             @keyword.control
(keyword_switch)         @keyword.control
(keyword_endswitch)      @keyword.control
(keyword_select)         @keyword.control
(keyword_endselect)      @keyword.control
(keyword_case)           @keyword.control
(keyword_with)           @keyword.control
(keyword_endwith)        @keyword.control
(keyword_exitloop)       @keyword.control
(keyword_continueloop)   @keyword.control
(keyword_continuecase)   @keyword.control

; Return/exit are conceptually keyword.return
(keyword_return) @keyword.return
(keyword_exit)   @keyword.return

; Declaration keywords
(keyword_local)  @keyword
(keyword_global) @keyword
(keyword_dim)    @keyword
(keyword_const)  @keyword
(keyword_static) @keyword
(keyword_enum)   @keyword
(keyword_byref)  @keyword

; Word-form logical operators
(keyword_and) @keyword.operator
(keyword_or)  @keyword.operator
(keyword_not) @keyword.operator

; Directive keywords (all rendered as preprocessor-ish)
(keyword_include)                @keyword.directive
(keyword_includeonce)            @keyword.directive
(keyword_region)                 @keyword.directive
(keyword_endregion)              @keyword.directive
(keyword_requireadmin)           @keyword.directive
(keyword_notrayicon)             @keyword.directive
(keyword_pragma)                 @keyword.directive
(keyword_onautoitstartregister)  @keyword.directive

; Generic catchall directive (#AutoIt3Wrapper_* etc.)
(directive_name) @keyword.directive
(directive_args) @string.special

; --- Functions --------------------------------------------------------------

; Definitions
(function_declaration
  name: (identifier) @function)

; Calls. Built-ins and user-defined calls are partitioned via the regex,
; so each identifier-in-call-position gets exactly one capture and the
; theme renders them distinctly.

; Built-in functions (curated top-20).
((call_expression
  function: (identifier) @function.builtin)
 (#match? @function.builtin "^(?i)(MsgBox|ConsoleWrite|FileOpen|FileRead|FileClose|StringFormat|StringLen|StringSplit|Run|RunWait|ObjCreate|IsArray|IsString|IsNumber|UBound|DllCall|HotKeySet|AutoItSetOption|Send|Sleep|Mod)$"))

; User-defined calls (everything else in identifier-call position).
((call_expression
  function: (identifier) @function.call)
 (#not-match? @function.call "^(?i)(MsgBox|ConsoleWrite|FileOpen|FileRead|FileClose|StringFormat|StringLen|StringSplit|Run|RunWait|ObjCreate|IsArray|IsString|IsNumber|UBound|DllCall|HotKeySet|AutoItSetOption|Send|Sleep|Mod)$"))

; Method calls — when the callee is a member access, highlight the property
; as the method name.
(call_expression
  function: (member_expression
    property: (identifier) @function.method))

(call_expression
  function: (implicit_member_expression
    property: (identifier) @function.method))

; Member access — property
(member_expression
  property: (identifier) @property)
(implicit_member_expression
  property: (identifier) @property)

; --- Include path -----------------------------------------------------------

(include_path_content) @string.special.path
; Standalone string used as #include "path/to/file.au3" is already @string.

; --- Operators (symbolic anonymous tokens) ----------------------------------

["+" "-" "*" "/" "^" "&"]            @operator
["=" "==" "<>" "<" "<=" ">" ">="]    @operator
["+=" "-=" "*=" "/=" "&="]           @operator

; --- Punctuation ------------------------------------------------------------

["(" ")" "[" "]"] @punctuation.bracket
"," @punctuation.delimiter
"." @punctuation.delimiter

; Include-path angle brackets are punctuation, not the < / > operators.
(include_path "<" @punctuation.bracket)
(include_path ">" @punctuation.bracket)
