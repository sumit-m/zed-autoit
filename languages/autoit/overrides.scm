; Syntactic scope captures used by Zed to override editor behavior inside
; strings and comments — bracket auto-close suppression (via `not_in` in
; config.toml's brackets entries) and completion / snippet suppression both
; key off these scopes.
;
; The `.inclusive` suffix on `line_comment` extends the scope through the
; trailing newline so the cursor at end-of-line is still considered "inside
; comment" — without it, the scope ends right at the last comment character
; and behavior outside that point reverts to normal.

(string) @string

(line_comment) @comment.inclusive
(block_comment) @comment
