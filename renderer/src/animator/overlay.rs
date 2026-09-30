//! What an effect draws over a stage, and over the footer, frame by frame.

use super::effect::{Effect, Kind};
use crate::ansi::{RESET, strip};
use crate::model::Run;
use crate::table::STAGES;
use crate::table::marks::marks;

const STAGE_PASS_COLOURS: [&str; 3] = ["\u{1b}[1;33m", "\u{1b}[1;32m", "\u{1b}[32m"];
const TIMEOUT_COLOURS: [&str; 4] = ["\u{1b}[1;33m", "\u{1b}[33m", "\u{1b}[1;33m", "\u{1b}[33m"];
/// A failed stage's cell flares red and cools, frame by frame, then shows as the row draws it.
const FAILURE_GLOW: [&str; 6] = ["1;97;48;5;196", "1;97;48;5;160", "1;97;48;5;124", "1;91;48;5;88", "1;91;48;5;52", "1;91"];

/// The stage's mark as its row shows it once the stage has finished.
#[must_use]
pub fn stage_text(run: &Run, stage: &str) -> Option<String> {
    run.stage(stage)?;
    let index = STAGES.iter().position(|name| *name == stage)?;
    Some(marks(run, ' ')[index].0.to_string())
}

/// What `effect` draws over the stage text `text` this frame.
#[must_use]
pub fn stage_overlay(effect: &Effect, text: &str) -> Option<String> {
    match effect.kind {
        Kind::StagePass => Some(flash(effect.frame, text, &STAGE_PASS_COLOURS)),
        Kind::Timeout => Some(flash(effect.frame, text, &TIMEOUT_COLOURS)),
        Kind::Failure => glow(effect.frame, text),
        Kind::Success => sparkle(effect, text),
        Kind::Conflict => None,
    }
}

fn flash(frame: usize, text: &str, colours: &[&str]) -> String {
    format!("{}{}{RESET}", colours[frame.min(colours.len() - 1)], strip(text))
}

fn glow(frame: usize, text: &str) -> Option<String> {
    FAILURE_GLOW.get(frame).map(|code| format!("\u{1b}[{code}m{}{RESET}", strip(text)))
}

fn sparkle(effect: &Effect, text: &str) -> Option<String> {
    let plain: Vec<char> = strip(text).chars().collect();
    let position = effect.frame.checked_sub(stagger(&effect.stage)).filter(|p| *p <= plain.len())?;
    let cell = |(i, c): (usize, &char)| format!("\u{1b}[{}m{c}", if i == position { "1;33" } else { "32" });
    Some(format!("{}{RESET}", plain.iter().enumerate().map(cell).collect::<String>()))
}

fn stagger(stage: &str) -> usize {
    match stage {
        "build" => 2,
        "fast" => 4,
        "slow" => 6,
        _ => 0,
    }
}
