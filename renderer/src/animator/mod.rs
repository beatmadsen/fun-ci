//! Everything that moves: the header animations and the effects over stages
//! and the footer, driven by the events Ruby sends.

mod backdrop;
mod caption;
mod cast;
mod draw;
mod effect;
mod footer;
mod header;
mod lamp;
pub mod looks;
mod marks;
mod playing;
mod queue;
mod resting;

use std::mem;

pub use cast::{Cast, MILESTONES, seed_at};
pub use draw::Places;
pub use effect::{Effect, Kind};
pub use header::HEADER_HEIGHT;
pub use lamp::{LAMP_AT, lamp};
pub use resting::{Outcome, Resting, resting};

use crate::animation::Scene;
use crate::model::{Board, Event, Moment, Run, Stage};
use ratatui::buffer::Buffer;
use header::Header;
use playing::Playing;

/// Plays animations over the board.
#[derive(Debug)]
pub struct Animator {
    playing: Playing,
    header: Header,
    pending: Vec<Event>,
    cast: Cast,
}

impl Animator {
    #[must_use]
    pub fn new(cast: Cast) -> Self {
        Self { playing: Playing::default(), header: Header::new(cast.idle()), pending: Vec::new(), cast }
    }

    /// Where each run's row and marks are this frame, for the stage effects.
    pub fn set_places(&mut self, places: Places) {
        self.playing.set_places(places);
    }

    /// Takes an event into account at the next frame, against that frame's runs.
    pub fn queue(&mut self, event: Event) {
        self.pending.push(event);
    }

    /// Whether anything but the looping idle and running animations is
    /// playing, or an event waits to be played.
    #[must_use]
    pub fn animating(&self) -> bool {
        !self.pending.is_empty() || self.playing.busy() || self.header.playing_event()
    }

    /// How often the header needs drawing when nothing else moves, in milliseconds.
    #[must_use]
    pub fn frame_ms(&self) -> u64 {
        self.header.frame_ms()
    }

    /// Draws this frame's animations into `buf` over `board` as of `at`, then
    /// advances the stage effects. Returns the name of the header animation drawn.
    pub fn render(&mut self, buf: &mut Buffer, board: &Board, at: Moment) -> String {
        let runs = &board.runs;
        self.take_events(runs, at.play_ms);
        self.follow_runs(runs, at);
        self.header.seek(at.play_ms);
        let showing = self.header.showing().to_string();
        self.header.draw(buf, board.streak);
        self.playing.draw(buf, runs, at.play_ms);
        showing
    }

    fn take_events(&mut self, runs: &[Run], play_ms: u64) {
        for event in &mem::take(&mut self.pending) {
            self.apply(event, runs, play_ms);
        }
    }

    fn apply(&mut self, event: &Event, runs: &[Run], play_ms: u64) {
        event.animation.iter().for_each(|name| self.cast.pin(name));
        if let Some(scene) = self.cast.for_milestone(&event.name) {
            self.header.trigger(scene);
        }
        if let (Some(Kind::Conflict), Some(run_id)) = (Kind::for_event(&event.name, "", ""), event.run_id) {
            self.playing.start(Kind::Conflict, (run_id, ""), play_ms);
        }
        let Some((run, stage)) = target(event, runs) else { return };
        if let Some(kind) = Kind::for_event(&event.name, &stage.status, run.status()) {
            self.playing.start(kind, (run.id, &stage.stage), play_ms);
        }
    }

    /// Shows the rocket while a run runs, and rests on the latest outcome,
    /// or a quiet scene once nothing has happened for a while.
    fn follow_runs(&mut self, runs: &[Run], at: Moment) {
        let running = runs.iter().any(|run| run.status() == "running");
        let resting = resting(runs, at.board_ms);
        let rest = self.resting_scene(resting, running, at.play_ms);
        let rocket = running.then(|| self.cast.running());
        self.header.follow(rocket, rest, resting.lamp());
    }

    fn resting_scene(&mut self, resting: Resting, running: bool, play_ms: u64) -> &'static dyn Scene {
        if running || !matches!(resting, Resting::Quiet(_)) {
            self.cast.wake();
        }
        match resting {
            Resting::Calm => self.cast.rest("passed"),
            Resting::Warning => self.cast.rest("failed"),
            Resting::Quiet(_) => self.cast.quiet(play_ms),
        }
    }
}

fn target<'r>(event: &Event, runs: &'r [Run]) -> Option<(&'r Run, &'r Stage)> {
    let run = runs.iter().find(|run| Some(run.id) == event.run_id)?;
    Some((run, run.stage(event.stage.as_deref()?)?))
}
