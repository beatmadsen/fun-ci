//! The animated header: idle stars, a rocket while anything runs, and an
//! event animation (success or failure) that plays once over both.

use crate::animation::Animation;

/// Rows the header occupies.
pub const HEADER_HEIGHT: usize = 14;
const ERASE_LINE: &str = "\u{1b}[K";

/// One animation, when it started, and the frame it is on.
#[derive(Debug, Clone)]
pub struct Player {
    animation: Animation,
    started_ms: Option<u64>,
    frame: usize,
}

impl Player {
    #[must_use]
    pub fn new(animation: Animation) -> Self {
        Self { animation, started_ms: None, frame: 0 }
    }

    #[must_use]
    pub fn finished(&self) -> bool {
        !self.animation.playback().looped && self.frame >= self.animation.frames().len()
    }

    /// This frame's lines, each centred in `width` and erased to its end.
    #[must_use]
    pub fn lines(&self, width: u16) -> Vec<String> {
        let frames = self.animation.frames();
        let index = if self.animation.playback().looped { self.frame % frames.len().max(1) } else { self.frame };
        let centre = |line: &crate::animation::StyledLine| {
            let pad = usize::from(width).saturating_sub(line.width()) / 2;
            format!("{}{}{ERASE_LINE}", " ".repeat(pad), line.ansi())
        };
        frames.get(index).map(|frame| frame.iter().map(centre).collect()).unwrap_or_default()
    }

    /// Moves to the frame due at `play_ms`; the first call starts the animation.
    pub fn seek(&mut self, play_ms: u64) {
        let started = *self.started_ms.get_or_insert(play_ms);
        let frame_ms = u64::from(self.animation.playback().frame_ms.max(1));
        self.frame = usize::try_from(play_ms.saturating_sub(started) / frame_ms).unwrap_or(usize::MAX);
    }
}

/// Which header animation shows, and all of them advancing together.
#[derive(Debug, Clone)]
pub struct Header {
    idle: Player,
    running: Option<Player>,
    event: Option<Player>,
}

impl Header {
    #[must_use]
    pub fn new(idle: Animation) -> Self {
        Self { idle: Player::new(idle), running: None, event: None }
    }

    /// Shows `rocket` from its first frame, unless it is already showing.
    pub fn start_running(&mut self, rocket: &Animation) {
        self.running.get_or_insert_with(|| Player::new(rocket.clone()));
    }

    pub fn stop_running(&mut self) {
        self.running = None;
    }

    /// Plays `animation` once over the idle and running animations.
    pub fn trigger(&mut self, animation: &Animation) {
        self.event = Some(Player::new(animation.clone()));
    }

    /// The header's lines this frame, padded to `HEADER_HEIGHT` and centred.
    #[must_use]
    pub fn lines(&self, width: u16) -> Vec<String> {
        let lines = self.active().lines(width);
        let spare = HEADER_HEIGHT.saturating_sub(lines.len());
        let blank = |n| vec![ERASE_LINE.to_string(); n];
        [blank(spare / 2), lines, blank(spare - spare / 2)].concat()
    }

    /// Moves every animation to the frame due at `play_ms`.
    pub fn seek(&mut self, play_ms: u64) {
        self.idle.seek(play_ms);
        self.running.iter_mut().chain(self.event.iter_mut()).for_each(|player| player.seek(play_ms));
    }

    /// Whether an event animation is still playing.
    #[must_use]
    pub fn playing_event(&self) -> bool {
        self.event.as_ref().is_some_and(|player| !player.finished())
    }

    /// The name of the animation `lines` draws.
    #[must_use]
    pub fn showing(&self) -> &str {
        self.active().animation.name()
    }

    fn active(&self) -> &Player {
        let event = self.event.as_ref().filter(|_| self.playing_event());
        event.or(self.running.as_ref()).unwrap_or(&self.idle)
    }
}
