//! Where each animation lands on the screen.

use super::effect::Effect;
use super::footer::footer_overlay;
use super::header::{HEADER_HEIGHT, Header};
use super::overlay::{stage_column, stage_overlay, stage_text};
use crate::model::Run;
use crate::screen::Screen;

/// The header animation's lines, from the top row.
pub fn header(screen: &mut Screen, header: &Header) {
    for (i, line) in header.lines(screen.width()).iter().enumerate() {
        screen.write_at(1 + i, 1, line);
    }
}

/// Each effect over its stage's text, on its run's row.
pub fn stages(screen: &mut Screen, effects: &[Effect], runs: &[Run]) {
    for (row, col, text) in effects.iter().filter_map(|effect| placed(effect, runs)) {
        screen.write_at(row, col, &text);
    }
}

/// The footer banner of the most important effect that has one, on the line
/// below the last run.
pub fn footer(screen: &mut Screen, effects: &[Effect], runs: &[Run]) {
    let banner = most_important(effects).and_then(|effect| footer_overlay(effect, screen.width()));
    if let Some(text) = banner {
        screen.write_at(HEADER_HEIGHT + runs.len() * 2 + 1, 1, &format!("{text}\u{1b}[K"));
    }
}

fn placed(effect: &Effect, runs: &[Run]) -> Option<(usize, usize, String)> {
    let index = runs.iter().position(|run| run.id == effect.run_id)?;
    let run = &runs[index];
    let overlay = stage_overlay(effect, &stage_text(run, &effect.stage)?)?;
    Some((HEADER_HEIGHT + 1 + index * 2, stage_column(run, &effect.stage)?, overlay))
}

fn most_important(effects: &[Effect]) -> Option<&Effect> {
    let candidates = effects.iter().filter(|e| e.kind.has_footer() && !e.finished());
    candidates.fold(None, |best: Option<&Effect>, e| match best {
        Some(b) if b.kind.priority() >= e.kind.priority() => Some(b),
        _ => Some(e),
    })
}
