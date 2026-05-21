//! Zed extension entry point for AutoIt language support.
//!
//! Responsibilities:
//!   1. Grammar + queries: declared in extension.toml (`[grammars.autoit]`)
//!      and the `languages/autoit/` query files. These work without any
//!      Rust code — the extension was grammar-only through v0.0.x.
//!   2. LSP launcher: resolves the `autoit-lsp` binary (PATH first, then
//!      auto-download from the GitHub release) and tells Zed how to spawn it.
//!   3. LSP settings forwarder: pulls the user's `lsp.autoit-lsp.*` block
//!      out of settings.json and hands it to Zed for delivery to the server.
//!      Zed does NOT do this automatically — without these two opt-in
//!      methods the LSP gets empty init options + an empty
//!      `workspace/didChangeConfiguration` payload.
//!
//! Binary resolution order (Option B, locked in CLAUDE.md):
//!   1. `worktree.which("autoit-lsp")` / `worktree.which("autoit-lsp.exe")` —
//!      lets developers + power users override the bundled binary by
//!      dropping one on $PATH (matches the dev workflow we use ourselves).
//!   2. An in-process / on-disk cache from a previous launch of the same
//!      extension version.
//!   3. The latest GitHub Release of `sumit-m/autoit-lsp`, asset selected
//!      per-platform via `zed::current_platform()`.
//!
//! Each downloaded binary lives under a version-keyed directory
//! (`autoit-lsp-<version>/`) inside the extension's data dir. On every
//! resolution we sweep sibling `autoit-lsp-*` directories that don't match
//! the current version — keeps disk usage bounded after extension updates.

use std::fs;

use zed_extension_api::{
    self as zed,
    serde_json::Value,
    settings::LspSettings,
    Architecture, DownloadedFileType, GithubReleaseOptions, LanguageServerId,
    LanguageServerInstallationStatus, Os, Result,
};

/// GitHub repo to pull autoit-lsp releases from. The CI workflow over there
/// publishes per-platform release assets matching the names in
/// `asset_spec_for_platform`. Don't rename — coordinated across both repos.
const LSP_REPO: &str = "sumit-m/autoit-lsp";

/// Name of the binary Zed should launch. Also the name we look for on PATH.
const LSP_BINARY_NAME: &str = "autoit-lsp";

struct AutoItExtension {
    /// Cached binary path from the last successful resolution. `None` until
    /// the extension instance has resolved at least once. Stored as a plain
    /// path string (Zed's WASI sandbox uses string paths throughout).
    cached_binary_path: Option<String>,
}

/// Per-platform release-asset spec derived from `zed::current_platform()`.
/// Asset name format is fixed by the CI workflow at
/// `autoit-lsp-<target-triple>.<ext>`, e.g.
/// `autoit-lsp-x86_64-pc-windows-msvc.zip`.
struct AssetSpec {
    asset_name: String,    // e.g. "autoit-lsp-x86_64-pc-windows-msvc.zip"
    archive_root: String,  // dir inside the archive, e.g. "autoit-lsp-x86_64-pc-windows-msvc"
    binary_name: String,   // "autoit-lsp.exe" on Windows, "autoit-lsp" elsewhere
    file_type: DownloadedFileType,
}

fn asset_spec_for_platform() -> Result<AssetSpec> {
    let (os, arch) = zed::current_platform();
    // The triples here MUST match the matrix in
    // sumit-m/autoit-lsp/.github/workflows/release.yml. If a new target
    // is added there, add the case here too.
    let target_triple = match (os, arch) {
        (Os::Windows, Architecture::X8664) => "x86_64-pc-windows-msvc",
        (Os::Linux, Architecture::X8664) => "x86_64-unknown-linux-gnu",
        (Os::Mac, Architecture::Aarch64) => "aarch64-apple-darwin",
        // Mac Intel + Linux ARM aren't published yet. Surface a clear
        // error so the user knows it's a platform-coverage gap, not a
        // setup mistake on their end.
        _ => {
            return Err(format!(
                "autoit-lsp doesn't yet ship a binary for {os:?} / {arch:?}. \
                 Currently published targets: x86_64 Windows, x86_64 Linux, \
                 aarch64 macOS. Open an issue if you'd like another target added."
            ));
        }
    };

    let archive_root = format!("autoit-lsp-{target_triple}");
    let (extension, file_type) = if matches!(os, Os::Windows) {
        ("zip", DownloadedFileType::Zip)
    } else {
        ("tar.gz", DownloadedFileType::GzipTar)
    };

    Ok(AssetSpec {
        asset_name: format!("{archive_root}.{extension}"),
        archive_root,
        binary_name: if matches!(os, Os::Windows) {
            "autoit-lsp.exe".into()
        } else {
            "autoit-lsp".into()
        },
        file_type,
    })
}

impl AutoItExtension {
    /// Resolve where the LSP binary lives. See module-level doc-comment for
    /// the priority order.
    fn binary_path(
        &mut self,
        lsp_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<String> {
        // Tier 1: $PATH override (dev + power user workflow). When this hits,
        // we skip the auto-download entirely — the user has explicitly
        // chosen which binary to use.
        if let Some(path) = worktree
            .which(LSP_BINARY_NAME)
            .or_else(|| worktree.which(&format!("{LSP_BINARY_NAME}.exe")))
        {
            return Ok(path);
        }

        // Tier 2: in-process cache hit (same extension instance asked
        // before).
        if let Some(path) = self.cached_binary_path.as_ref() {
            if fs::metadata(path).map(|m| m.is_file()).unwrap_or(false) {
                return Ok(path.clone());
            }
        }

        // Tier 3: download from latest GitHub release.
        zed::set_language_server_installation_status(
            lsp_id,
            &LanguageServerInstallationStatus::CheckingForUpdate,
        );
        let release = zed::latest_github_release(
            LSP_REPO,
            GithubReleaseOptions {
                require_assets: true,
                pre_release: false,
            },
        )
        .map_err(|e| format!("failed to fetch latest autoit-lsp release: {e}"))?;

        let spec = asset_spec_for_platform()?;
        // Version key for the cache dir. Strip a leading 'v' so we get
        // `autoit-lsp-0.3.0/` not `autoit-lsp-v0.3.0/` — slightly cleaner
        // and avoids confusion if Cargo's package version is mixed in.
        let version = release.version.trim_start_matches('v');
        let version_dir = format!("autoit-lsp-{version}");
        let binary_path = format!(
            "{version_dir}/{archive_root}/{binary_name}",
            archive_root = spec.archive_root,
            binary_name = spec.binary_name,
        );

        // Already downloaded this exact version on a previous launch?
        if fs::metadata(&binary_path)
            .map(|m| m.is_file())
            .unwrap_or(false)
        {
            self.cached_binary_path = Some(binary_path.clone());
            cleanup_orphan_versions(&version_dir);
            return Ok(binary_path);
        }

        // Fresh download.
        let asset = release
            .assets
            .iter()
            .find(|a| a.name == spec.asset_name)
            .ok_or_else(|| {
                format!(
                    "release {} doesn't have a `{}` asset — open an issue \
                     at https://github.com/sumit-m/autoit-lsp/issues if this \
                     persists.",
                    release.version, spec.asset_name
                )
            })?;

        zed::set_language_server_installation_status(
            lsp_id,
            &LanguageServerInstallationStatus::Downloading,
        );
        zed::download_file(&asset.download_url, &version_dir, spec.file_type).map_err(|e| {
            format!(
                "failed to download {} from {}: {e}",
                spec.asset_name, asset.download_url
            )
        })?;

        // Verify the binary landed where we expect — guard against the
        // archive layout changing without anyone noticing.
        if !fs::metadata(&binary_path)
            .map(|m| m.is_file())
            .unwrap_or(false)
        {
            return Err(format!(
                "download succeeded but `{binary_path}` doesn't exist — the \
                 release-asset layout may have changed."
            ));
        }

        // On Unix the binary needs the executable bit (archives extract
        // with the permission set from the original tarball, but Zed's
        // sandbox normalises it to 644 — this re-sets +x).
        let (os, _) = zed::current_platform();
        if !matches!(os, Os::Windows) {
            zed::make_file_executable(&binary_path).map_err(|e| {
                format!("failed to mark {binary_path} executable: {e}")
            })?;
        }

        self.cached_binary_path = Some(binary_path.clone());
        cleanup_orphan_versions(&version_dir);
        zed::set_language_server_installation_status(
            lsp_id,
            &LanguageServerInstallationStatus::None,
        );
        Ok(binary_path)
    }
}

/// Remove sibling `autoit-lsp-*` directories that don't match the current
/// version. Run on every binary resolution so disk usage stays bounded
/// after extension updates. Best-effort: errors are ignored — failing to
/// clean an old version directory shouldn't break the LSP launch.
fn cleanup_orphan_versions(keep: &str) {
    let entries = match fs::read_dir(".") {
        Ok(e) => e,
        Err(_) => return,
    };
    for entry in entries.flatten() {
        let name = entry.file_name();
        let name_str = name.to_string_lossy();
        if !name_str.starts_with("autoit-lsp-") {
            continue;
        }
        if name_str.as_ref() == keep {
            continue;
        }
        // Skip anything that isn't a directory — we only create directories
        // for our cache, but third-party files matching the prefix shouldn't
        // be deleted.
        if !entry.path().is_dir() {
            continue;
        }
        let _ = fs::remove_dir_all(entry.path());
    }
}

impl zed::Extension for AutoItExtension {
    fn new() -> Self {
        Self {
            cached_binary_path: None,
        }
    }

    fn language_server_command(
        &mut self,
        language_server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        let command = self.binary_path(language_server_id, worktree)?;
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
        // `workspace/didChangeConfiguration` push. The LSP parses the same
        // shape from either delivery channel.
        Ok(LspSettings::for_worktree(server_id.as_ref(), worktree)?.settings)
    }
}

zed::register_extension!(AutoItExtension);
