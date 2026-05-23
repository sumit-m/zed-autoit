<h1 align="center">AutoIt for Zed</h1>

<p align="center">
  <img src="./robot.png" alt="Pixel-art weathered robot holding a magnifying glass and a club — mascot for the AutoIt for Zed extension" width="500">
</p>

**First-class editing support for <a href="https://www.autoitscript.com/site/autoit/">AutoIt v3</a> (<code>.au3</code>, <code>.a3x</code>) in the <a href="https://zed.dev">Zed editor</a>** — syntax highlighting, live diagnostics, hover docs for ~3,500 built-in and library functions, outline, go-to-definition, find-references, completion, cross-file <code>#include</code> resolution, snippets, and one-keystroke task runners for the AutoIt toolchain.

## Features

- **Syntax highlighting** via a from-scratch [tree-sitter grammar](https://github.com/sumit-m/tree-sitter-autoit) — 182 corpus tests, 99.96% pass rate against AutoIt's bundled Examples directory (2,662 files).
- **Live diagnostics** via the [autoit-lsp](https://github.com/sumit-m/autoit-lsp) language server, which wraps AutoIt's official `Au3Check.exe`. Edits surface red squiggles ~400ms after you stop typing (configurable) without needing to save.
- **Hover docs** for **3,542 functions** (core builtins + UDF library) from the official AutoIt help — signature, summary, parameter list, return value, and a footer link to the canonical docs page.
- **Go-to-definition** — jump to where any function, variable, or constant is declared. Works within the current file and across `#include`d files.
- **Find-references** — locate all usages of the symbol under the cursor, scope-aware (local variables only match within their function).
- **Completion** — context-aware popup for variables (`$`), macros (`@`), functions (built-in and user-defined), and symbols from included files. Also completes file paths inside `#include` directives.
- **Document symbols / outline** — functions, `Global`/`Const`/`Enum` declarations, `#Region` blocks.
- **Brackets, indentation, outline navigation** — the usual editor affordances.
- **19 bundled snippets** for `Func`, `If`/`ElseIf`/`Else`, `For`, `While`, `Switch`, `Region`, `MsgBox`, `ConsoleWrite`, hot-keys, etc.
- **7 task definitions** for run / Au3Check / Aut2Exe compile / Aut2Exe with GUI options / Au3Info / Koda Form Designer / kill running script. Zero-config for standard installer-based AutoIt installations (registry discovery).

## Requirements

- **Zed** 0.180 or later (uses `schema_version = 1`).
- **Any OS** — the extension and language server build and run on Windows, Linux, and macOS. Syntax highlighting, outline, hover docs, go-to-definition, find-references, completion, and snippets work everywhere.
- **Windows + AutoIt v3 installed** if you want live diagnostics or the bundled tasks. Both rely on AutoIt's Windows-only binaries (`Au3Check.exe`, `AutoIt3.exe`, `Aut2Exe.exe`). AutoIt install can be:
  - **Default installer** (`C:\Program Files (x86)\AutoIt3\`) — fully zero-config.
  - **Custom installer location** — fully zero-config, the registry tells us where.
  - **Portable / unzipped** at a non-default path — set `au3checkPath` in your Zed settings (see [Configuration](#configuration)).
- On Linux/macOS the LSP starts cleanly and serves hover, outline, go-to-definition, find-references, and completion; diagnostics are silently disabled. Task definitions are still installed but won't run since they invoke `*.exe` binaries.

## Installation

Open Zed → command palette (`cmd-shift-p` / `ctrl-shift-p`) → `extensions` → search **AutoIt** → install.

That's it for installer-based AutoIt setups. The Au3Check path is discovered automatically via the Windows registry.

## Configuration

All settings live under `lsp.autoit-lsp.settings` in your `settings.json` (`%APPDATA%\Zed\settings.json` user-wide, or `.zed/settings.json` per-workspace).

```json
{
  "lsp": {
    "autoit-lsp": {
      "settings": {
        "au3checkPath": "D:\\Tools\\AutoIt3\\Au3Check.exe",
        "debounceMs": 400
      }
    }
  }
}
```

| Setting | Default | Description |
|---|---|---|
| `au3checkPath` | (registry discovery) | Absolute path to `Au3Check.exe`. Needed only for portable / unzipped AutoIt installs at non-default locations. If set to a non-existent file, the server logs a warning and falls back to registry discovery — so a stale setting doesn't break the LSP after you install AutoIt normally. |
| `debounceMs` | `400` | Milliseconds to wait after the last keystroke before re-linting. Clamped to `[50, 5000]`. The first edit after open or save lints immediately regardless. |

## Tasks

All tasks scope to AutoIt files only and show up in the Command Palette under **task: spawn**. AutoIt's install directory is discovered at run-time from the Windows registry, so no editing is needed for standard installs.

| Task | What it does |
|---|---|
| **AutoIt: Run** *filename* | Runs the script, streaming `ConsoleWrite()` output to the terminal in real time. |
| **AutoIt: Check** *filename* **(Au3Check)** | Lints the file with the official `Au3Check.exe` — preview of what the LSP shows as you edit. |
| **AutoIt: Compile** *filename* **(Aut2Exe)** | Direct compile to a standalone Windows binary with defaults. |
| **AutoIt: Compile** *filename* **with Options (AutoIt3Wrapper GUI)** | Launches the SciTE-bundled `AutoIt3Wrapper.au3` with `/ShowGui` so you pick icon / version info / console mode before compile. |
| **AutoIt: Launch Au3Info** | The window-info inspector GUI. |
| **AutoIt: Launch Koda Form Designer** | The drag-and-drop GUI builder bundled with SciTE4AutoIt3. |
| **AutoIt: Kill** *filename* | SciTE-equivalent of Ctrl+Break — terminates the `AutoIt3.exe` process running the current file. |

## Limitations

### Permanent constraints

- **Diagnostics + tasks are Windows-only.** They invoke AutoIt's official binaries (`Au3Check.exe`, `AutoIt3.exe`, `Aut2Exe.exe`), which AutoIt itself only ships for Windows. Everything else — syntax, outline, hover, go-to-definition, find-references, completion, and snippets — works on Linux and macOS too.
- **`#region` doesn't fold** (Zed limitation — [zed-industries/zed#22703](https://github.com/zed-industries/zed/issues/22703) upstream). The grammar correctly identifies region blocks; Zed's folding mechanism doesn't currently support non-leaf-token multi-node folds.
- **Outline panel is flat** (Zed limitation — the LSP emits a proper hierarchy with parameters as children of functions and contents nested under regions, but Zed's outline panel renders flat with indentation instead of expand/collapse — tracked at [zed-industries/zed#23095](https://github.com/zed-industries/zed/issues/23095)).
- **Snippets fire inside strings/comments** (Zed limitation — the extension's `overrides.scm` correctly identifies string/comment scopes and suppresses word/LSP completions there, but Zed's snippet provider doesn't currently honor the per-scope override — tracked at [zed-industries/zed#21578](https://github.com/zed-industries/zed/pull/21578)). The existing override blocks will start working automatically once that is fixed upstream.

## Troubleshooting

**Diagnostics don't appear.** Check that AutoIt is installed and `Au3Check.exe` exists. If you have a portable / non-installer AutoIt, set `au3checkPath` (see [Configuration](#configuration)). The server logs `Au3Check.exe not found in registry, default path, or initializationOptions.au3checkPath — diagnostics disabled` to stderr if discovery fails.

**Hover shows nothing on a function I defined myself.** If you're hovering a call that's defined in the same file or an `#include`d file, confirm the definition uses the standard `Func Name(...)` syntax and that the file has been saved (the index is built from the on-disk content). The built-in catalog covers ~3,542 documented AutoIt builtins and UDF library functions; user-defined functions show a signature popup once indexed. Macros (`@CRLF`, `@ScriptDir`, etc.) don't have hover — they're covered by completion detail strings instead.

**Tasks fail with `'x86' is not recognized` or similar PowerShell errors.** Make sure Zed's default shell is PowerShell, not `cmd.exe` or bash. The tasks use PowerShell's `&` call operator and the registry-lookup pattern; running them through a different shell needs a workspace `tasks.json` override with your preferred invocation.

**The squiggle lands on `)` instead of the function name.** Should be fixed in v0.3.0 — please [file an issue](https://github.com/sumit-m/zed-autoit/issues) with the source line and the message Au3Check produced.

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgments

- The Au3Check invocation pattern and stdout-parsing regex are adapted from [loganch/AutoIt-VSCode](https://github.com/loganch/AutoIt-VSCode) (MIT). Their prior art validated the wrapping approach.
- Builtin function metadata is derived from the official AutoIt v3 documentation at <https://www.autoitscript.com/autoit3/docs/> — only structured fields (name, signature, parameters, summary, return value) are extracted, not the full prose.
- The tree-sitter grammar lives in a sibling repo: [tree-sitter-autoit](https://github.com/sumit-m/tree-sitter-autoit).
- The language server lives in a sibling repo: [autoit-lsp](https://github.com/sumit-m/autoit-lsp).
