//! The status board: header space, the table (`table`) and its footer, and
//! the animations over them.

use crate::animator::{Animator, HEADER_HEIGHT, Places};
use crate::ansi::{DIM, paint};
use crate::art::output::{Depth, escape};
use crate::model::Board;
use crate::screen::Screen;
use crate::spinner::Spinner;
use crate::table::footer::footer_line;
use crate::table::page::page;
use crate::table::{Drawn, Frame, draw};

const EMPTY_STATE: [&str; 7] = [
    "",
    "",
    "          No runs yet.",
    "",
    "          Set it up:    fun-ci init --everything",
    "          Then commit:  each commit starts a run",
    "",
];

pub use crate::model::Moment;

/// The footer and the blank line above it.
const BELOW_TABLE: usize = 2;

/// Draws boards into a frame buffer.
#[derive(Debug)]
pub struct BoardView {
    screen: Screen,
    spinner: Spinner,
    animator: Animator,
    depth: Depth,
    /// The animation clock at the first frame, where the table's own clock starts.
    started_ms: Option<u64>,
}

impl BoardView {
    #[must_use]
    pub fn new(animator: Animator) -> Self {
        Self { screen: Screen::new(80), spinner: Spinner::default(), animator, depth: Depth::TrueColour, started_ms: None }
    }

    /// Draws the header and the table in `depth`'s colours from the next frame.
    pub fn set_depth(&mut self, depth: Depth) {
        self.depth = depth;
        self.animator.set_depth(depth);
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

    pub fn clear(&mut self) {
        self.screen.clear();
    }

    /// Starts a frame: cursor home, spinner one step on.
    pub fn begin_frame(&mut self) {
        self.screen.home();
        self.spinner.advance();
    }

    pub fn resize(&mut self, cols: u16) {
        self.screen.set_width(cols);
    }

    /// Draws `board` as of `at` on a terminal `rows` high, returning the
    /// name of the header animation drawn.
    pub fn render(&mut self, board: &Board, at: Moment, rows: u16) -> String {
        self.screen.set_height(rows);
        self.screen.write_at(HEADER_HEIGHT + 1, 1, "");
        self.render_body(board, at, rows);
        self.screen.clear_below();
        self.animator.render(&mut self.screen, board, at)
    }

    /// The bytes drawn since the last take.
    pub fn take(&mut self) -> Vec<u8> {
        self.screen.take()
    }

    fn render_body(&mut self, board: &Board, at: Moment, rows: u16) {
        if board.runs.is_empty() {
            self.render_empty(rows);
        } else {
            self.render_rows(board, at, rows);
        }
    }

    /// The empty state's lines, as many as fit below the header without the
    /// last newline scrolling the screen.
    fn render_empty(&mut self, rows: u16) {
        let quit = paint(DIM, "  q quit");
        let fitting = usize::from(rows).saturating_sub(HEADER_HEIGHT + 1);
        for line in EMPTY_STATE.iter().copied().chain([quit.as_str()]).take(fitting) {
            self.screen.println(line);
        }
    }

    /// The table, blank lines down to the footer, the stale trunks' note
    /// above it when the table had to go flat, and the footer on the last row.
    fn render_rows(&mut self, board: &Board, at: Moment, rows: u16) {
        let height = usize::from(rows).saturating_sub(HEADER_HEIGHT);
        let play_ms = at.play_ms.saturating_sub(*self.started_ms.get_or_insert(at.play_ms));
        let frame = Frame { now_ms: at.board_ms, play_ms, spinner: self.spinner.current(), width: self.screen.width(), depth: self.depth };
        let drawn = draw(board, frame, height.saturating_sub(BELOW_TABLE));
        let body = page(board, &drawn, frame, height.saturating_sub(1));
        for line in &body {
            self.screen.println(line);
        }
        self.animator.set_places(places(&drawn, body.len(), self.depth));
        if height > 1 {
            self.screen.print_last(&footer_line(board, &drawn, frame));
        }
    }
}

/// Where the table's rows and marks landed, 1-based, for the stage effects,
/// and the line under the table for an effect's banner.
fn places(drawn: &Drawn, body: usize, depth: Depth) -> Places {
    let top = HEADER_HEIGHT + 1;
    let rows = drawn.rows.iter().map(|(run, line)| (*run, top + line)).collect();
    let block = drawn.block.map(|(run, paper)| (run, escape(48, paper, depth)));
    Places { rows, strip: drawn.columns.strip + 1, banner: top + drawn.lines.len().min(body), block }
}
