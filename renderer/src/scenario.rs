//! Scenario files (`contract/scenarios/*.jsonl`): protocol messages plus the
//! headless-only `resize` and `tick`.

use std::fs;
use std::path::Path;

use crate::protocol::{Inbound, parse};

/// Reads every message of a scenario file.
///
/// # Errors
/// When the file cannot be read or a line is not a message.
pub fn load(path: &Path) -> Result<Vec<Inbound>, String> {
    let text = fs::read_to_string(path).map_err(|e| format!("{}: {e}", path.display()))?;
    let lines = text.lines().filter(|line| !line.trim().is_empty());
    lines.enumerate().map(|(i, line)| parse(line).map_err(|e| format!("line {}: {e:?}", i + 1))).collect()
}

/// The terminal size (cols, rows) in force at each tick.
#[must_use]
pub fn tick_sizes(messages: &[Inbound]) -> Vec<(u16, u16)> {
    let sized = messages.iter().scan((80, 24), |size, message| {
        if let Inbound::Resize { cols, rows } = message {
            *size = (*cols, *rows);
        }
        Some((matches!(message, Inbound::Tick { .. }), *size))
    });
    sized.filter(|(tick, _)| *tick).map(|(_, size)| size).collect()
}
