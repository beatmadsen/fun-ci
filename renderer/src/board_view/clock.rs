//! The table's clock: the spinner one step on each frame, and the animation
//! clock counted from the first frame, so a live session and a headless
//! replay of the same frames draw the table alike.

use crate::model::Moment;
use crate::spinner::Spinner;
use crate::table::Frame;

/// The spinner, and the animation clock at the first frame.
#[derive(Debug, Default)]
pub struct TableClock {
    spinner: Spinner,
    started_ms: Option<u64>,
}

impl TableClock {
    /// Moves the spinner one step on.
    pub fn tick(&mut self) {
        self.spinner.advance();
    }

    /// What the table draws with at `at` on a screen `width` wide.
    pub fn frame(&mut self, at: Moment, width: u16) -> Frame {
        let play_ms = at.play_ms.saturating_sub(*self.started_ms.get_or_insert(at.play_ms));
        Frame { now_ms: at.board_ms, play_ms, spinner: self.spinner.current(), width }
    }
}
