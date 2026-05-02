//! Workspace focus on slot press.
//!
//! Translates a `(modifier, letter)` pair into a synthetic global keystroke
//! that the user's window manager picks up. mcmonad's keymap handles the
//! workspace switch; we just play the chord the user already configured.
//!
//! macOS only — uses `osascript` ↔ AppleScript ↔ `System Events`. On Linux
//! we'd reach for `wtype` / `xdotool`; not implemented yet.

use anyhow::{Context, Result, anyhow};

#[derive(Clone, Copy, Debug)]
pub enum Modifier {
    Command,
    Control,
    Option,
    Shift,
}

impl Modifier {
    pub fn parse(s: &str) -> Result<Self> {
        Ok(match s.to_ascii_lowercase().as_str() {
            "cmd" | "command" | "super" => Self::Command,
            "ctrl" | "control" => Self::Control,
            "opt" | "option" | "alt" => Self::Option,
            "shift" => Self::Shift,
            other => return Err(anyhow!(
                "unknown workspace modifier `{other}` (use cmd|ctrl|opt|shift)"
            )),
        })
    }

    fn applescript_using(self) -> &'static str {
        match self {
            Self::Command => "command down",
            Self::Control => "control down",
            Self::Option  => "option down",
            Self::Shift   => "shift down",
        }
    }
}

/// Send `<modifier>+<letter>` as a synthetic keystroke. `letter` should be
/// a single ASCII char; the workspace name in `slots.toml` doubles as the
/// letter (e.g. `workspace = "v"` → mod+V).
pub async fn focus_workspace(modifier: Modifier, letter: &str) -> Result<()> {
    if letter.chars().count() != 1 {
        return Err(anyhow!(
            "workspace `{letter}` must be a single character to map to a chord"
        ));
    }
    let ch = letter.chars().next().unwrap();
    if !ch.is_ascii_alphanumeric() {
        return Err(anyhow!(
            "workspace `{letter}` must be ascii alphanumeric"
        ));
    }
    // `keystroke "v" using {command down}` — note the surrounding {}.
    let script = format!(
        r#"tell application "System Events" to keystroke "{ch}" using {{{using}}}"#,
        using = modifier.applescript_using()
    );
    let status = tokio::process::Command::new("osascript")
        .arg("-e")
        .arg(&script)
        .status()
        .await
        .context("spawning osascript")?;
    if !status.success() {
        return Err(anyhow!(
            "osascript exited with {status} (Accessibility permission for cogcast-q0?)"
        ));
    }
    Ok(())
}
