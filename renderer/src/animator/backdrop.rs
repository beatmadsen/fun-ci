//! What the header shows when no event scene plays: the running scene while
//! a run runs, else the resting scene for the latest outcome (acceptance-
//! tests.md, AT-7.5), else the idle night sky. Each loops from when it first
//! showed.

use super::header::Player;
use crate::animation::Scene;

#[derive(Debug, Clone)]
pub struct Backdrop {
    idle: Player,
    running: Option<Player>,
    rest: Option<Player>,
}

impl Backdrop {
    #[must_use]
    pub fn new(idle: &'static dyn Scene) -> Self {
        Self { idle: Player::new(idle), running: None, rest: None }
    }

    /// Shows the `running` scene while there is one, from its start unless it
    /// already shows, and rests on `rest` while there is one, from its start
    /// unless it is the one resting already.
    pub fn follow(&mut self, running: Option<&'static dyn Scene>, rest: Option<&'static dyn Scene>) {
        self.running = running.map(|scene| self.running.take().unwrap_or_else(|| Player::new(scene)));
        let same = |player: &Player| rest.is_some_and(|scene| player.name() == scene.name());
        self.rest = rest.map(|scene| self.rest.take().filter(same).unwrap_or_else(|| Player::new(scene)));
    }

    pub fn seek(&mut self, play_ms: u64) {
        self.idle.seek(play_ms);
        self.running.iter_mut().chain(self.rest.iter_mut()).for_each(|player| player.seek(play_ms));
    }

    #[must_use]
    pub fn showing(&self) -> &Player {
        self.running.as_ref().or(self.rest.as_ref()).unwrap_or(&self.idle)
    }
}
