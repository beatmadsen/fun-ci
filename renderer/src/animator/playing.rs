//! The effects playing over the board: each effect's banner, if it has one,
//! and the effect on its stage's mark (`marks`), both where `Places` says
//! the board put them this frame.

use ratatui::buffer::Buffer;

use super::draw::{self, Places};
use super::effect::{Effect, Kind};
use super::looks::mark_effects;
use super::marks::Marks;
use crate::model::Run;

/// The effects playing, their marks' effects, and where the board put things.
#[derive(Debug, Default)]
pub struct Playing {
    effects: Vec<Effect>,
    marks: Marks,
    places: Places,
}

impl Playing {
    /// Starts `kind` for `run_id`'s `stage` at `play_ms`, in place of the same effect there.
    pub fn start(&mut self, kind: Kind, (run_id, stage): (u64, &str), play_ms: u64) {
        self.effects.retain(|effect| !effect.is_for(kind, run_id, stage));
        self.effects.push(Effect::new(kind, (run_id, stage), play_ms));
        let mark = (run_id, stage.to_string());
        self.marks.cancel(&mark);
        for (after_ms, effect) in mark_effects(kind, stage) {
            self.marks.start(&mark, play_ms + after_ms, effect);
        }
    }

    /// Where each run's row and marks are this frame.
    pub fn set_places(&mut self, places: Places) {
        self.places = places;
    }

    /// Whether any effect is still playing.
    #[must_use]
    pub fn busy(&self) -> bool {
        !self.effects.is_empty() || self.marks.playing()
    }

    /// Draws every effect as of `play_ms` into `buf`, over `runs`' board.
    pub fn draw(&mut self, buf: &mut Buffer, runs: &[Run], play_ms: u64) {
        self.effects.retain(|effect| !effect.finished(play_ms));
        self.marks.draw(buf, &self.places, play_ms);
        draw::footer(buf, &self.effects, (runs, &self.places), play_ms);
    }
}
