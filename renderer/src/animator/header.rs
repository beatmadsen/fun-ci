//! The animated header: idle stars, a rocket while anything runs, and an
//! event animation (success or failure) that plays once over both.

use crate::animation::Animation;

/// Rows the header occupies.
pub const HEADER_HEIGHT: usize = 14;
const ERASE_LINE: &str = "\u{1b}[K";

/// One animation and how far it has played.
#[derive(Debug, Clone)]
pub struct Player {
    animation: Animation,
    frame: usize,
}

impl Player {
    #[must_use]
    pub fn new(animation: Animation) -> Self {
        Self { animation, frame: 0 }
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

    pub fn advance(&mut self) {
        self.frame += 1;
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

    pub fn advance(&mut self) {
        self.idle.advance();
        self.running.iter_mut().chain(self.event.iter_mut()).for_each(Player::advance);
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
