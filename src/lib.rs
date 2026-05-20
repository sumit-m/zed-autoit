//! Zed extension entry point for AutoIt language support.
//!
//! Three responsibilities:
//!   1. Grammar + queries: declared in extension.toml (`[grammars.autoit]`)
//!      and the `languages/autoit/` query files. These work without any
//!      Rust code — the extension was grammar-only through v0.0.x.
//!   2. LSP launcher: tells Zed where to find `autoit-lsp` (our Au3Check
//!      wrapper, built from the sibling `autoit-lsp` repo) and how to
//!      spawn it.
//!   3. LSP settings forwarder: pulls the user's `lsp.autoit-lsp.*` block
//!      out of settings.json and hands it to Zed for delivery to the
//!      server. Zed does NOT do this automatically — without these two
//!      opt-in methods the LSP gets empty init options + an empty
//!      `workspace/didChangeConfiguration` payload.

use zed_extension_api::{
    self as zed,
    serde_json::Value,
    settings::LspSettings,
    LanguageServerId, Result,
};

struct AutoItExtension;

impl zed::Extension for AutoItExtension {
    fn new() -> Self {
        Self
    }

    fn language_server_command(
        &mut self,
        _language_server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        // Try PATH first so non-dev users don't need to know an absolute
        // path. `worktree.which` consults the host's PATH inside Zed's
        // extension sandbox.
        let command = worktree
            .which("autoit-lsp")
            .or_else(|| worktree.which("autoit-lsp.exe"))
            .ok_or_else(|| {
                "autoit-lsp binary not found on PATH. Build it from the \
                 sibling `autoit-lsp` repo (`cargo build --release`) and \
                 add `target/release/` to your PATH, or copy the binary \
                 into a dir that's already on PATH."
                    .to_string()
            })?;

        Ok(zed::Command {
            command,
            args: vec![],
            env: Default::default(),
        })
    }

    fn language_server_initialization_options(
        &mut self,
        server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<Option<Value>> {
        // Pass through `lsp.autoit-lsp.initialization_options` from
        // settings.json so autoit-lsp receives it in `initialize`.
        Ok(LspSettings::for_worktree(server_id.as_ref(), worktree)?.initialization_options)
    }

    fn language_server_workspace_configuration(
        &mut self,
        server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<Option<Value>> {
        // Pass through `lsp.autoit-lsp.settings` for the periodic
        // `workspace/didChangeConfiguration` push. The LSP parses the
        // same shape from either delivery channel.
        Ok(LspSettings::for_worktree(server_id.as_ref(), worktree)?.settings)
    }
}

zed::register_extension!(AutoItExtension);
