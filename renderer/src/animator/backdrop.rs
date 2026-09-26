//! What the header shows when no event scene plays: the running scene while
//! a run runs, else the resting scene: the latest outcome, or a quiet scene
//! once nothing has happened for a while (acceptance-tests.md, AT-7.5,
//! AT-7.7). Each loops from when it first showed.

use super::header::Player;
use super::resting::Outcome;
use crate::animation::Scene;

#[derive(Debug, Clone)]
pub struct Backdrop {
    running: Option<Player>,
    rest: Player,
    lamp: Option<Outcome>,
}

impl Backdrop {
    /// Rests on `first` until told otherwise.
    #[must_use]
    pub fn new(first: &'static dyn Scene) -> Self {
        Self { running: None, rest: Player::new(first), lamp: None }
    }

    /// Shows the `running` scene while there is one, from its start unless it
    /// already shows, and rests on `rest`, from its start unless it is the one
    /// resting already, under the `lamp` for the latest outcome, if any.
    pub fn follow(&mut self, running: Option<&'static dyn Scene>, rest: &'static dyn Scene, lamp: Option<Outcome>) {
        self.lamp = lamp;
        self.running = running.map(|scene| self.running.take().unwrap_or_else(|| Player::new(scene)));
        if self.rest.name() != rest.name() {
            self.rest = Player::new(rest);
        }
    }

    pub fn seek(&mut self, play_ms: u64) {
        self.rest.seek(play_ms);
        self.running.iter_mut().for_each(|player| player.seek(play_ms));
    }

    /// The lamp to paint over the scene showing: none while a run runs.
    #[must_use]
    pub fn lamp(&self) -> Option<Outcome> {
        self.lamp.filter(|_| self.running.is_none())
    }

    #[must_use]
    pub fn showing(&self) -> &Player {
        self.running.as_ref().unwrap_or(&self.rest)
    }
}
