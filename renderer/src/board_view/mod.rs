//! The status board, composed in a ratatui buffer: the header's scene across
//! the top, the table under it and its footer on the last line (`body`), and
//! the effects over them (`animator`). ratatui's terminal sends only the cells
//! that changed since the last frame.
//!
//! The table and the animations never see each other: the table says where
//! it put each run's row and marks, and `body` passes that on as the places
//! the effects land (`Places`).

mod body;
mod clock;

use std::convert::Infallible;

use ratatui::Terminal;
use ratatui::layout::{Position, Rect};

use crate::animator::Animator;
use crate::model::Board;
use crate::output::backend::AnsiBackend;
use crate::output::depth::Depth;
use body::body;
use clock::TableClock;

pub use crate::model::Moment;

/// Draws boards on a terminal of bytes.
#[derive(Debug)]
pub struct BoardView {
    terminal: Terminal<AnsiBackend>,
    clock: TableClock,
    animator: Animator,
    /// Whether the next frame clears the screen first.
    clearing: bool,
}

impl BoardView {
    #[must_use]
    pub fn new(animator: Animator) -> Self {
        let terminal = sure(Terminal::new(AnsiBackend::new((80, 24), Depth::TrueColour)));
        Self { terminal, clock: TableClock::default(), animator, clearing: false }
    }

    /// Draws in `depth`'s colours, all of the screen again from the next frame.
    pub fn set_depth(&mut self, depth: Depth) {
        self.terminal.backend_mut().set_depth(depth);
        self.clear();
    }

    pub fn animator(&mut self) -> &mut Animator {
        &mut self.animator
    }

    /// How often the header needs drawing when nothing else moves, in milliseconds.
    #[must_use]
    pub fn frame_ms(&self) -> u64 {
        self.animator.frame_ms()
    }

    #[must_use]
    pub fn animating(&self) -> bool {
        self.animator.animating()
    }

    /// Clears the screen at the start of the next frame, which draws all of it.
    pub fn clear(&mut self) {
        self.clearing = true;
    }

    /// Starts a frame: the spinner one step on.
    pub fn begin_frame(&mut self) {
        self.clock.tick();
    }

    /// The terminal is `size` (cols, rows); a new size clears it at the next frame.
    pub fn resize(&mut self, size: (u16, u16)) {
        self.terminal.backend_mut().resize(size);
    }

    /// Draws `board` as of `at`, returning the name of the header animation drawn.
    pub fn render(&mut self, board: &Board, at: Moment) -> String {
        self.settle();
        let Self { terminal, clock, animator, .. } = self;
        let mut showing = String::new();
        sure(terminal.draw(|frame| {
            let buf = frame.buffer_mut();
            animator.set_places(body(buf, board, clock.frame(at, buf.area.width)));
            showing = animator.render(buf, board, at);
        }));
        showing
    }

    /// The bytes drawn since the last take.
    pub fn take(&mut self) -> Vec<u8> {
        self.terminal.backend_mut().take()
    }

    /// Clears the screen once if asked to, or if its size changed, which clears it anyway.
    fn settle(&mut self) {
        let size = self.terminal.backend().size_now();
        let area = Rect::from((Position::ORIGIN, ratatui::layout::Size::new(size.0, size.1)));
        if area != self.terminal.get_frame().area() {
            sure(self.terminal.resize(area));
        } else if self.clearing {
            sure(self.terminal.clear());
        }
        self.clearing = false;
    }
}

/// What cannot fail, since the backend only writes to memory.
fn sure<T>(result: Result<T, Infallible>) -> T {
    match result {
        Ok(value) => value,
        Err(never) => match never {},
    }
}
