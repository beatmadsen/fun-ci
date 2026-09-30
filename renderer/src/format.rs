//! How raw protocol values read on screen: durations, ages, hashes, names.

use std::path::Path;

/// `300` -> `0.3s`, `1000` -> `1s`, `62500` -> `1m02`.
#[must_use]
pub fn duration(ms: u64) -> String {
    match ms {
        60_000.. => format!("{}m{:02}", ms / 60_000, ms % 60_000 / 1000),
        _ if ms.is_multiple_of(1000) => format!("{}s", ms / 1000),
        _ => format!("{:.1}s", f64::from(u32::try_from(ms).unwrap_or(u32::MAX)) / 1000.0),
    }
}

/// Whole seconds from `since` (epoch seconds) to `now_ms` (epoch milliseconds),
/// truncated toward zero.
#[must_use]
pub fn seconds_since(since: i64, now_ms: i64) -> i64 {
    (now_ms - since * 1000) / 1000
}

/// `now`, `5m`, `2h`, `3d`: short, so every row's age ends in the same place.
#[must_use]
pub fn age(since: i64, now_ms: i64) -> String {
    match seconds_since(since, now_ms) {
        ..60 => "now".to_string(),
        s @ ..3600 => format!("{}m", s / 60),
        s @ ..86_400 => format!("{}h", s / 3600),
        s => format!("{}d", s / 86_400),
    }
}

/// The first seven characters of a SHA.
#[must_use]
pub fn short_sha(sha: &str) -> &str {
    sha.char_indices().nth(7).map_or(sha, |(end, _)| &sha[..end])
}

/// The project's directory name.
#[must_use]
pub fn project_name(path: &str) -> String {
    Path::new(path).file_name().map_or(String::new(), |n| n.to_string_lossy().into_owned())
}

/// How many columns `text` fills on screen: two for each character of
/// Chinese, Japanese or Korean, and the like; one for most others.
#[must_use]
pub fn columns(text: &str) -> usize {
    unicode_width::UnicodeWidthStr::width(text)
}

/// `text` in at most `room` columns, its end replaced by `…` when cut.
#[must_use]
pub fn cut(text: &str, room: usize) -> String {
    if columns(text) <= room {
        return text.to_string();
    }
    let mut filled = 0;
    let fitting = text.chars().take_while(|c| {
        filled += unicode_width::UnicodeWidthChar::width(*c).unwrap_or(0);
        filled < room
    });
    fitting.chain(['…']).collect()
}
