//! Everything that moves: the header animations and the effects over stages
//! and the footer, driven by the events Ruby sends.

mod cast;
mod draw;
mod effect;
mod footer;
mod header;
mod overlay;

use std::mem;

pub use cast::{Cast, seed_at};
pub use effect::{Effect, Kind};
pub use header::HEADER_HEIGHT;

use crate::model::{Event, Run, Stage};
use crate::screen::Screen;
use header::Header;

/// Plays animations over the board.
#[derive(Debug, Clone)]
pub struct Animator {
    effects: Vec<Effect>,
    header: Header,
    pending: Vec<Event>,
    cast: Cast,
}

impl Animator {
    #[must_use]
    pub fn new(cast: Cast) -> Self {
        Self { effects: Vec::new(), header: Header::new(cast.idle()), pending: Vec::new(), cast }
    }

    /// Takes an event into account at the next frame, against that frame's runs.
    pub fn queue(&mut self, event: Event) {
        self.pending.push(event);
    }

    /// Whether anything but the looping idle and running animations is
    /// playing, or an event waits to be played.
    #[must_use]
    pub fn animating(&self) -> bool {
        !self.pending.is_empty() || !self.effects.is_empty() || self.header.playing_event()
    }

    /// Draws this frame's animations over the board as of `play_ms`, then
    /// advances the stage effects. Returns the name of the header animation drawn.
    pub fn render(&mut self, screen: &mut Screen, runs: &[Run], play_ms: u64) -> String {
        self.take_events(runs);
        self.follow_running(runs);
        self.header.seek(play_ms);
        let showing = self.header.showing().to_string();
        self.draw(screen, runs);
        self.advance();
        showing
    }

    fn take_events(&mut self, runs: &[Run]) {
        let events = mem::take(&mut self.pending);
        for name in events.iter().filter_map(|e| e.animation.as_deref()) {
            self.cast.pin(name);
        }
        for event in &events {
            self.apply(event, runs);
        }
    }

    fn apply(&mut self, event: &Event, runs: &[Run]) {
        let Some((run, stage)) = target(event, runs) else { return };
        if let Some(kind) = Kind::for_event(&event.name, &stage.status, run.status()) {
            self.add(kind, run.id, &stage.stage);
        }
    }

    fn add(&mut self, kind: Kind, run_id: u64, stage: &str) {
        self.effects.retain(|effect| !effect.is_for(kind, run_id, stage));
        self.effects.push(Effect::new(kind, run_id, stage));
        match kind {
            Kind::Failure => self.header.trigger(&self.cast.failure()),
            Kind::Success => self.header.trigger(&self.cast.success()),
            Kind::Timeout | Kind::StagePass => {}
        }
    }

    fn follow_running(&mut self, runs: &[Run]) {
        if runs.iter().any(|run| run.status() == "running") {
            self.header.start_running(&self.cast.running());
        } else {
            self.header.stop_running();
        }
    }

    fn draw(&self, screen: &mut Screen, runs: &[Run]) {
        screen.save_cursor();
        draw::header(screen, &self.header);
        draw::stages(screen, &self.effects, runs);
        draw::footer(screen, &self.effects, runs);
        screen.restore_cursor();
    }

    fn advance(&mut self) {
        self.effects.iter_mut().for_each(|effect| effect.frame += 1);
        self.effects.retain(|effect| !effect.finished());
    }
}

fn target<'r>(event: &Event, runs: &'r [Run]) -> Option<(&'r Run, &'r Stage)> {
    let run = runs.iter().find(|run| Some(run.id) == event.run_id)?;
    Some((run, run.stage(event.stage.as_deref()?)?))
}
