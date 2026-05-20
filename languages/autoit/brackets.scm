; Parser-level bracket pairs. The list in config.toml handles auto-close
; on type; this query is what Zed uses for "go to matching bracket" and
; rainbow-bracket-style themes.

("(" @open ")" @close)
("[" @open "]" @close)
(include_path "<" @open ">" @close)
