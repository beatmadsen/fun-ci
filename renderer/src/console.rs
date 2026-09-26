//! What is on show and how it is drawn, shared by the live session and the
//! headless replay, so both draw the same bytes for the same state and clock.

use crate::animation::Library;
use crate::animator::{Animator, Cast};
pub use crate::board_view::Moment;
use crate::board_view::BoardView;
use crate::model::{Board, Event};

/// Frame interval while anything animates or runs.
const BUSY_MS: u64 = 100;

/// The latest board, the animations over it, and the terminal size.
#[derive(Debug)]
pub struct Console {
    view: BoardView,
    board: Board,
    size: (u16, u16),
}

impl Console {
    /// `seed` drives the random choice of success and failure animations.
    #[must_use]
    pub fn new(library: &Library, seed: u64, size: (u16, u16)) -> Self {
        Self { view: BoardView::new(Animator::new(Cast::new(library.clone(), seed))), board: Board::default(), size }
    }

    /// Draws the header in `depth`'s colours from the next frame.
    pub fn set_depth(&mut self, depth: crate::art::output::Depth) {
        self.view.animator().set_depth(depth);
    }

    /// Clears the screen at the start of the next frame.
    pub fn clear(&mut self) {
        self.view.clear();
    }

    /// Replaces the board on show.
    pub fn show(&mut self, board: &Board) {
        self.board = board.clone();
    }

    /// Plays whatever animation `event` calls for, from the next frame.
    pub fn queue(&mut self, event: Event) {
        self.view.animator().queue(event);
    }

    /// The terminal size (cols, rows) the next frame is drawn for.
    pub fn resize(&mut self, size: (u16, u16)) {
        self.size = size;
    }

    #[must_use]
    pub fn size(&self) -> (u16, u16) {
        self.size
    }

    /// Whether the next frames change without a new board: an animation is
    /// playing or queued, or a run is running.
    #[must_use]
    pub fn busy(&self) -> bool {
        self.view.animating() || self.board.runs.iter().any(|run| run.status() == "running")
    }

    /// How long after one frame the next is due: a tenth of a second while
    /// busy, otherwise as often as the header's scene needs.
    #[must_use]
    pub fn frame_ms(&self) -> u64 {
        if self.busy() { BUSY_MS } else { self.view.frame_ms() }
    }

    /// Draws one frame as of `at`: the bytes, and the header animation shown.
    pub fn frame(&mut self, at: Moment) -> (Vec<u8>, String) {
        self.view.begin_frame();
        self.view.resize(self.size.0);
        let showing = self.view.render(&self.board, at, self.size.1);
        (self.view.take(), showing)
    }
}
