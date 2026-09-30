//! The banner an effect shows in the footer: four looks, each held for 0.8
//! seconds, blank at either end.

use ratatui::style::{Color, Modifier, Style};

use super::effect::{Effect, Kind};
use crate::model::{Run, stage_noun};

const HOLD_MS: u64 = 800;

/// The banner `effect` shows at `play_ms`, if any, and how; `runs` name a conflict's branch and trunk.
#[must_use]
pub fn banner(effect: &Effect, runs: &[Run], play_ms: u64) -> Option<(String, Style)> {
    let look_at = usize::try_from(effect.elapsed_ms(play_ms) / HOLD_MS).unwrap_or(usize::MAX);
    let (colour, weight, text) = look(effect, runs, look_at)?;
    Some((text, Style::default().fg(colour).add_modifier(weight)))
}

type Look = (Color, Modifier, String);

fn look(effect: &Effect, runs: &[Run], look_at: usize) -> Option<Look> {
    let (colour, text) = match effect.kind {
        Kind::Failure => (Color::Rgb(0xFF, 0x9C, 0x8C), failure_text(look_at, &effect.stage)?),
        Kind::Success => (Color::Rgb(0x9C, 0xF0, 0xCC), success_text(look_at)?),
        Kind::Conflict => (Color::Rgb(0xDA, 0xB4, 0xFF), conflict_text(look_at, &conflict(effect, runs)?)?),
        Kind::Timeout | Kind::StagePass => return None,
    };
    Some((colour, weight(look_at), text))
}

/// Bold, then plain, then dim.
fn weight(look: usize) -> Modifier {
    match look {
        1 => Modifier::BOLD,
        3 => Modifier::DIM,
        _ => Modifier::empty(),
    }
}

/// "feat/search conflicts with main", from the run the effect is for.
fn conflict(effect: &Effect, runs: &[Run]) -> Option<String> {
    let run = runs.iter().find(|run| run.id == effect.run_id)?;
    Some(format!("{} conflicts with {}", run.commit.branch, run.trunk.as_ref()?.trunk))
}

fn conflict_text(look: usize, text: &str) -> Option<String> {
    match look {
        1 => Some(text.to_uppercase()),
        2 | 3 => Some(text.to_string()),
        _ => None,
    }
}

/// The failure banner, naming the stage in full: `>>> THE FAST SUITE FAILED <<<`.
fn failure_text(look: usize, stage: &str) -> Option<String> {
    let down = stage_noun(stage);
    let up = down.to_uppercase();
    match look {
        1 => Some(format!(">>> {up} FAILED <<<")),
        2 => Some(format!(">> {down} failed <<")),
        3 => Some(format!("> {down} failed <")),
        _ => None,
    }
}

fn success_text(look: usize) -> Option<String> {
    match look {
        1 => Some("* * * NICE! * * *".to_string()),
        2 => Some(". + . * NICE! * . + .".to_string()),
        3 => Some("' . + .  nice  . + . '".to_string()),
        _ => None,
    }
}
