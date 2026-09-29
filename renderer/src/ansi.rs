//! SGR colouring, byte-compatible with the 1.x Ruby `Ansi` module.

pub const RESET: &str = "\u{1b}[0m";
pub const DIM: &str = "2";

/// `text` in the SGR `code`, then a reset.
#[must_use]
pub fn paint(code: &str, text: &str) -> String {
    format!("\u{1b}[{code}m{text}{RESET}")
}

/// `text` with every CSI escape (`ESC [ digits/semicolons letter`) removed.
#[must_use]
pub fn strip(text: &str) -> String {
    let mut parts = text.split('\u{1b}');
    let head = parts.next().unwrap_or_default().to_string();
    head + &parts.map(after_escape).collect::<String>()
}

fn after_escape(part: &str) -> String {
    let params = part.strip_prefix('[').map(|rest| rest.trim_start_matches(|c: char| c.is_ascii_digit() || c == ';'));
    match params.filter(|rest| rest.starts_with(|c: char| c.is_ascii_alphabetic())) {
        Some(rest) => rest[1..].to_string(),
        None => format!("\u{1b}{part}"),
    }
}
