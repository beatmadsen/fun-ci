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

    /// Shows `rocket` from its start, unless it is already showing.
    pub fn start_running(&mut self, rocket: &'static dyn Scene) {
        self.running.get_or_insert_with(|| Player::new(rocket));
    }

    pub fn stop_running(&mut self) {
        self.running = None;
    }

    /// Rests on `scene`, from its start unless it is the one resting already.
    pub fn rest_on(&mut self, scene: &'static dyn Scene) {
        if self.rest.as_ref().is_none_or(|player| player.name() != scene.name()) {
            self.rest = Some(Player::new(scene));
        }
    }

    pub fn stop_resting(&mut self) {
        self.rest = None;
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
