//! How raw protocol values read on screen: durations, ages, hashes, names.

use std::path::Path;

const PROJECT_COLOURS: [u8; 10] = [31, 32, 33, 34, 35, 36, 91, 92, 93, 94];

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

/// `just now`, `5m ago`, `2h ago`.
#[must_use]
pub fn age(since: i64, now_ms: i64) -> String {
    match seconds_since(since, now_ms) {
        ..60 => "just now".to_string(),
        s @ ..3600 => format!("{}m ago", s / 60),
        s => format!("{}h ago", s / 3600),
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

/// The SGR colour code for a project name: CRC-32 of the name, so a project
/// keeps its colour across restarts.
#[must_use]
pub fn project_colour(name: &str) -> u8 {
    let index = crc32fast::hash(name.as_bytes()) % 10;
    PROJECT_COLOURS[usize::try_from(index).unwrap_or_default()]
}

/// The word a finished stage's status adds after its name: `Lint FAIL 2s`.
#[must_use]
pub fn finished_word(status: &str) -> Option<&'static str> {
    match status {
        "passed" => Some(""),
        "failed" => Some(" FAIL"),
        "timeout" => Some(" TIMEOUT"),
        _ => None,
    }
}

/// The label a stage is shown under, for the four stages fun-ci runs.
#[must_use]
pub fn stage_label(stage: &str) -> Option<&'static str> {
    match stage {
        "lint" => Some("Lint"),
        "build" => Some("Build"),
        "fast" => Some("Fast"),
        "slow" => Some("Slow"),
        _ => None,
    }
}
