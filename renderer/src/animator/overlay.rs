//! What an effect draws over a stage, and over the footer, frame by frame.

use super::effect::{Effect, Kind};
use crate::ansi::{BOLD_RED, RESET, paint, strip};
use crate::format::{duration, finished_word, project_name, stage_label};
use crate::model::{Run, Stage};

const STAGE_PASS_COLOURS: [&str; 3] = ["\u{1b}[1;33m", "\u{1b}[1;32m", "\u{1b}[32m"];
const TIMEOUT_COLOURS: [&str; 4] = ["\u{1b}[1;33m", "\u{1b}[33m", "\u{1b}[1;33m", "\u{1b}[33m"];
const PARTICLES: [(&str, &str); 7] = [
    ("*", "\u{1b}[1;31m"),
    (".*", "\u{1b}[1;31m"),
    (".+*.", "\u{1b}[38;5;208m"),
    ("*.+'", "\u{1b}[38;5;208m"),
    ("' .", "\u{1b}[38;5;52m"),
    (".", "\u{1b}[38;5;52m"),
    ("", ""),
];

/// The stage's text as its row shows it once the stage has finished.
#[must_use]
pub fn stage_text(run: &Run, stage: &str) -> Option<String> {
    let found = run.stage(stage)?;
    let name = stage_label(stage).unwrap_or(stage);
    let took = found.duration_ms.map_or("--".to_string(), duration);
    Some(match finished_word(&found.status) {
        Some(word) => format!("{name}{word} {took}"),
        None => format!("{name} --"),
    })
}

/// The 1-based column the stage's text starts at in its row.
#[must_use]
pub fn stage_column(run: &Run, stage: &str) -> Option<usize> {
    let project = run.commit.project.as_deref().map_or(0, |p| project_name(p).chars().count() + 2);
    let index = run.stages.iter().position(|s| s.stage == stage)?;
    let text_width = |s: &Stage| stage_text(run, &s.stage).map_or(0, |t| t.chars().count()) + 2;
    let before: usize = run.stages[..index].iter().map(text_width).sum();
    Some(2 + 7 + 2 + run.commit.branch.chars().count() + project + 2 + before + 1)
}

/// What `effect` draws over the stage text `text` this frame.
#[must_use]
pub fn stage_overlay(effect: &Effect, text: &str) -> Option<String> {
    match effect.kind {
        Kind::StagePass => Some(flash(effect.frame, text, &STAGE_PASS_COLOURS)),
        Kind::Timeout => Some(flash(effect.frame, text, &TIMEOUT_COLOURS)),
        Kind::Failure => flanks(effect.frame, text),
        Kind::Success => sparkle(effect, text),
    }
}

fn flash(frame: usize, text: &str, colours: &[&str]) -> String {
    format!("{}{}{RESET}", colours[frame.min(colours.len() - 1)], strip(text))
}

fn flanks(frame: usize, text: &str) -> Option<String> {
    let (chars, colour) = PARTICLES.get(frame)?;
    let plain = strip(text);
    if chars.is_empty() {
        return Some(plain);
    }
    let left: String = chars.chars().rev().collect();
    Some(format!("{colour}{left}{RESET} {} {colour}{chars}{RESET}", paint(BOLD_RED, &plain)))
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
