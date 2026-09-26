//! The header's queue of event scenes: each plays to its end, in the order
//! the events arrived (acceptance-tests.md, AT-7.4).

use std::collections::VecDeque;

use super::header::Player;
use crate::animation::Scene;

#[derive(Debug, Clone, Default)]
pub struct SceneQueue {
    waiting: VecDeque<&'static dyn Scene>,
    playing: Option<Player>,
}

impl SceneQueue {
    pub fn push(&mut self, scene: &'static dyn Scene) {
        self.waiting.push_back(scene);
    }

    /// Moves the scene playing to `play_ms`, and starts the next one there
    /// once it has played its length.
    pub fn seek(&mut self, play_ms: u64) {
        self.playing.iter_mut().for_each(|player| player.seek(play_ms));
        if self.playing().is_none() {
            self.playing = self.waiting.pop_front().map(Player::new);
            self.playing.iter_mut().for_each(|player| player.seek(play_ms));
        }
    }

    /// The scene playing, until it has played its length.
    #[must_use]
    pub fn playing(&self) -> Option<&Player> {
        self.playing.as_ref().filter(|player| !player.finished())
    }

    /// Whether a scene is playing or waiting to.
    #[must_use]
    pub fn busy(&self) -> bool {
        self.playing().is_some() || !self.waiting.is_empty()
    }
}
