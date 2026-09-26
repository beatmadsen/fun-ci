//! The animated header: a scene over the full width of the terminal. The
//! event scenes queued play one after another over the backdrop: the running,
//! resting or idle scene.

use super::backdrop::Backdrop;
use super::film::Film;
use super::queue::SceneQueue;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::cells::{CELL_PIXELS, encode};
use crate::art::output::Depth;
use crate::screen::Screen;

/// Rows the header occupies.
pub const HEADER_HEIGHT: usize = 14;

/// One scene and how long it has been playing.
#[derive(Debug, Clone)]
pub struct Player {
    scene: &'static dyn Scene,
    started_ms: Option<u64>,
    elapsed_ms: u64,
}

impl Player {
    #[must_use]
    pub fn new(scene: &'static dyn Scene) -> Self {
        Self { scene, started_ms: None, elapsed_ms: 0 }
    }

    #[must_use]
    pub fn name(&self) -> &'static str {
        self.scene.name()
    }

    #[must_use]
    pub fn finished(&self) -> bool {
        self.scene.length_ms().is_some_and(|length| self.elapsed_ms >= length)
    }

    /// Moves to `play_ms`; the first call starts the scene.
    pub fn seek(&mut self, play_ms: u64) {
        let started = *self.started_ms.get_or_insert(play_ms);
        self.elapsed_ms = play_ms.saturating_sub(started);
    }
}

/// Which scene shows, all of them moving on together, and what is on screen.
#[derive(Debug, Clone)]
pub struct Header {
    backdrop: Backdrop,
    queue: SceneQueue,
    film: Film,
}

impl Header {
    #[must_use]
    pub fn new(idle: &'static dyn Scene) -> Self {
        Self { backdrop: Backdrop::new(idle), queue: SceneQueue::default(), film: Film::new(Depth::TrueColour) }
    }

    pub fn set_depth(&mut self, depth: Depth) {
        self.film = Film::new(depth);
    }

    /// What shows when no event scene plays.
    pub fn backdrop(&mut self) -> &mut Backdrop {
        &mut self.backdrop
    }

    /// Queues `scene` to play once over the idle and running scenes.
    pub fn trigger(&mut self, scene: &'static dyn Scene) {
        self.queue.push(scene);
    }

    /// Moves every scene to `play_ms`.
    pub fn seek(&mut self, play_ms: u64) {
        self.backdrop.seek(play_ms);
        self.queue.seek(play_ms);
    }

    /// Paints the scene showing and draws the cells that changed.
    pub fn draw(&mut self, screen: &mut Screen) {
        let active = self.active();
        let mut canvas = Canvas::new(usize::from(screen.width()) * CELL_PIXELS.0, HEADER_HEIGHT * CELL_PIXELS.1);
        active.scene.paint(&mut canvas, active.elapsed_ms);
        canvas.tone();
        self.film.project(encode(&canvas), screen);
    }

    /// Whether an event scene is playing or waiting to.
    #[must_use]
    pub fn playing_event(&self) -> bool {
        self.queue.busy()
    }

    /// How often the scene showing needs drawing when nothing else moves.
    #[must_use]
    pub fn frame_ms(&self) -> u64 {
        self.active().scene.frame_ms()
    }

    /// The name of the scene `draw` paints.
    #[must_use]
    pub fn showing(&self) -> &'static str {
        self.active().scene.name()
    }

    fn active(&self) -> &Player {
        self.queue.playing().unwrap_or_else(|| self.backdrop.showing())
    }
}
