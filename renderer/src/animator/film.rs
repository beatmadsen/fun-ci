//! What the header last put on screen, so a frame draws only what changed.

use crate::art::cells::Cell;
use crate::art::output::{Depth, changed_spans, sgr_line};
use crate::screen::Screen;

/// The header's cells as last drawn, and the screen clear they were drawn after.
#[derive(Debug, Clone)]
pub struct Film {
    depth: Depth,
    shown: Option<Vec<Vec<Cell>>>,
    clears: u64,
}

impl Film {
    #[must_use]
    pub fn new(depth: Depth) -> Self {
        Self { depth, shown: None, clears: 0 }
    }

    /// Draws the cells of `frame` that differ from what is on screen; all of
    /// them if the screen was cleared since the last frame.
    pub fn project(&mut self, frame: Vec<Vec<Cell>>, screen: &mut Screen) {
        let shown = self.shown.take().filter(|_| self.clears == screen.clears());
        for span in changed_spans(shown.as_ref(), &frame) {
            let cells = &frame[span.row][span.col..span.col + span.len];
            screen.write_at(span.row + 1, span.col + 1, &sgr_line(cells, self.depth));
        }
        (self.shown, self.clears) = (Some(frame), screen.clears());
    }
}
