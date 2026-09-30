//! The effects playing on stages' marks, run by tachyonfx: each on the one
//! cell of its mark, which moves as the board does, and one at a time on a
//! mark, the latest replacing any before it. An effect waits for its start,
//! then plays from the exact time it was due, however the frames fall.

use ratatui::buffer::Buffer;
use ratatui::layout::Rect;
use tachyonfx::{Duration, Effect, EffectManager, RefRect, fx};

use super::draw::Places;
use crate::model::STAGES;

/// A mark: its run and its stage.
pub type Mark = (u64, String);

/// The marks' effects playing, those waiting to start and when, the cell each
/// playing one is on, and the animation clock at the last frame.
#[derive(Debug, Default)]
pub struct Marks {
    playing: EffectManager<Mark>,
    waiting: Vec<(u64, Mark, Effect)>,
    cells: Vec<(Mark, RefRect)>,
    last_ms: Option<u64>,
}

impl Marks {
    /// Plays `effect` on `mark` from `due_ms` by the animation clock.
    pub fn start(&mut self, mark: &Mark, due_ms: u64, effect: Effect) {
        self.waiting.push((due_ms, mark.clone(), effect));
    }

    /// Drops the effects waiting to start on `mark`.
    pub fn cancel(&mut self, mark: &Mark) {
        self.waiting.retain(|(_, waiting, _)| waiting != mark);
    }

    /// Whether any mark's effect is playing or waits to start.
    #[must_use]
    pub fn playing(&self) -> bool {
        !self.waiting.is_empty() || self.playing.is_running()
    }

    /// Moves every effect on to `play_ms` and draws it into `buf` where `places` put its mark.
    pub fn draw(&mut self, buf: &mut Buffer, places: &Places, play_ms: u64) {
        let since = play_ms.saturating_sub(self.last_ms.unwrap_or(play_ms));
        self.last_ms = Some(play_ms);
        self.cells.iter().for_each(|(mark, cell)| cell.set(at(places, mark).intersection(buf.area)));
        self.playing.process_effects(millis(since), buf, buf.area);
        let (due, waiting) = std::mem::take(&mut self.waiting).into_iter().partition(|(due_ms, _, _)| *due_ms <= play_ms);
        self.waiting = waiting;
        for (due_ms, mark, effect) in due {
            let mut effect = self.begin(&mark, RefRect::new(at(places, &mark).intersection(buf.area)), effect);
            effect.process(millis(play_ms - due_ms), buf, buf.area);
            self.playing.add_effect(effect);
        }
        if !self.playing() {
            self.cells.clear();
        }
    }

    /// `effect` on `mark`'s `cell`, in place of any before it there, ready to play.
    fn begin(&mut self, mark: &Mark, cell: RefRect, effect: Effect) -> Effect {
        self.cells.iter().filter(|(other, _)| other == mark).for_each(|(_, old)| old.set(Rect::default()));
        self.cells.retain(|(other, _)| other != mark);
        self.cells.push((mark.clone(), cell.clone()));
        self.playing.unique(mark.clone(), fx::dynamic_area(cell, effect))
    }
}

fn millis(ms: u64) -> Duration {
    Duration::from_millis(u32::try_from(ms).unwrap_or(u32::MAX))
}

/// The cell of `stage`'s mark on `run_id`'s row; none when its row is not on screen.
fn at(places: &Places, (run_id, stage): &Mark) -> Rect {
    let row = places.rows.iter().find(|(id, _)| id == run_id).map(|(_, row)| *row);
    let index = STAGES.iter().position(|name| name == stage);
    let cell = row.zip(index).and_then(|(row, index)| Some((u16::try_from(places.strip + 2 * index).ok()?, u16::try_from(row).ok()?)));
    cell.map_or_else(Rect::default, |(x, y)| Rect::new(x, y, 1, 1))
}
