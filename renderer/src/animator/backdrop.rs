//! What the header shows when no event scene plays: the running scene while
//! a run runs, else the resting scene: the latest outcome, or a quiet scene
//! once nothing has happened for a while (acceptance-tests.md, AT-7.5,
//! AT-7.7). Each loops from when it first showed.

use super::header::Player;
use crate::animation::Scene;

#[derive(Debug, Clone)]
pub struct Backdrop {
    running: Option<Player>,
    rest: Player,
}

impl Backdrop {
    /// Rests on `first` until told otherwise.
    #[must_use]
    pub fn new(first: &'static dyn Scene) -> Self {
        Self { running: None, rest: Player::new(first) }
    }

    /// Shows the `running` scene while there is one, from its start unless it
    /// already shows, and rests on `rest`, from its start unless it is the one
    /// resting already.
    pub fn follow(&mut self, running: Option<&'static dyn Scene>, rest: &'static dyn Scene) {
        self.running = running.map(|scene| self.running.take().unwrap_or_else(|| Player::new(scene)));
        if self.rest.name() != rest.name() {
            self.rest = Player::new(rest);
        }
    }

    pub fn seek(&mut self, play_ms: u64) {
        self.rest.seek(play_ms);
        self.running.iter_mut().for_each(|player| player.seek(play_ms));
    }

    #[must_use]
    pub fn showing(&self) -> &Player {
        self.running.as_ref().unwrap_or(&self.rest)
    }
}
