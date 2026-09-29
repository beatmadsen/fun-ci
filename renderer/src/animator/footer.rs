//! The banner an effect shows in the footer: four looks, each held for eight
//! frames, blank at either end.

use super::effect::{Effect, Kind};
use crate::ansi::RESET;
use crate::model::Run;

const HOLD: usize = 8;

/// The footer line `effect` shows this frame, if any; `runs` name a conflict's branch and trunk.
#[must_use]
pub fn footer_overlay(effect: &Effect, width: u16, runs: &[Run]) -> Option<String> {
    let (colour, text) = look(effect, runs)?;
    let pad = usize::from(width).saturating_sub(text.chars().count()) / 2;
    Some(format!("{}\u{1b}[{colour}m{text}{RESET}", " ".repeat(pad)))
}

fn look(effect: &Effect, runs: &[Run]) -> Option<(&'static str, String)> {
    match effect.kind {
        Kind::Failure => failure_look(effect.frame / HOLD, &effect.stage),
        Kind::Success => success_look(effect.frame / HOLD),
        Kind::Conflict => conflict_look(effect.frame / HOLD, &conflict(effect, runs)?),
        Kind::Timeout | Kind::StagePass => None,
    }
}

/// "feat/search conflicts with main", from the run the effect is for.
fn conflict(effect: &Effect, runs: &[Run]) -> Option<String> {
    let run = runs.iter().find(|run| run.id == effect.run_id)?;
    Some(format!("{} conflicts with {}", run.commit.branch, run.trunk.as_ref()?.trunk))
}

fn conflict_look(look: usize, text: &str) -> Option<(&'static str, String)> {
    match look {
        1 => Some(("1;35", text.to_uppercase())),
        2 => Some(("35", text.to_string())),
        3 => Some(("2;35", text.to_string())),
        _ => None,
    }
}

fn failure_look(look: usize, stage: &str) -> Option<(&'static str, String)> {
    let (up, down) = (stage.to_uppercase(), stage.to_lowercase());
    match look {
        1 => Some(("1;31", format!(">>> {up} FAILED <<<"))),
        2 => Some(("31", format!(">> {down} failed <<"))),
        3 => Some(("2;31", format!("> {down} failed <"))),
        _ => None,
    }
}

fn success_look(look: usize) -> Option<(&'static str, String)> {
    match look {
        1 => Some(("1;32", "* * * NICE! * * *".to_string())),
        2 => Some(("32", ". + . * NICE! * . + .".to_string())),
        3 => Some(("2;32", "' . + .  nice  . + . '".to_string())),
        _ => None,
    }
}
