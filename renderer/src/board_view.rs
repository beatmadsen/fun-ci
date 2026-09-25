//! The status board: header space, one row per run, footer, and the
//! animations over them, laid out as the 1.x `BoardRenderer` laid them out.

use crate::animator::{Animator, HEADER_HEIGHT};
use crate::ansi::{DIM, paint};
use crate::format::short_sha;
use crate::model::{Board, Run};
use crate::row::format_run;
use crate::screen::Screen;
use crate::spinner::Spinner;

const EMPTY_STATE: [&str; 7] = [
    "",
    "",
    "          No runs yet.",
    "",
    "          Set it up:    fun-ci init --everything",
    "          Then commit:  each commit starts a run",
    "",
];

/// Draws boards into a frame buffer.
#[derive(Debug)]
pub struct BoardView {
    screen: Screen,
    spinner: Spinner,
    animator: Animator,
}

impl BoardView {
    #[must_use]
    pub fn new(animator: Animator) -> Self {
        Self { screen: Screen::new(80), spinner: Spinner::default(), animator }
    }

    pub fn animator(&mut self) -> &mut Animator {
        &mut self.animator
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

    /// Draws `board` as of `now_ms` on a terminal `rows` high, returning the
    /// name of the header animation drawn.
    pub fn render(&mut self, board: &Board, now_ms: i64, rows: u16) -> String {
        self.screen.set_height(rows);
        self.screen.write_at(HEADER_HEIGHT + 1, 1, "");
        self.render_body(board, now_ms, rows);
        self.screen.clear_below();
        self.animator.render(&mut self.screen, &board.runs)
    }

    /// The bytes drawn since the last take.
    pub fn take(&mut self) -> Vec<u8> {
        self.screen.take()
    }

    fn render_body(&mut self, board: &Board, now_ms: i64, rows: u16) {
        if board.runs.is_empty() {
            self.render_empty();
        } else {
            self.render_rows(board, now_ms, rows);
        }
    }

    fn render_empty(&mut self) {
        for line in EMPTY_STATE {
            self.screen.println(line);
        }
        self.screen.println(&paint(DIM, "  q quit"));
    }

    fn render_rows(&mut self, board: &Board, now_ms: i64, rows: u16) {
        let lines = self.lines(board, now_ms, rows);
        self.render_lines(&lines, board.view.cursor);
        if !lines.is_empty() {
            self.screen.println("");
        }
        self.screen.println(&paint(DIM, &footer(board)));
    }

    fn lines(&self, board: &Board, now_ms: i64, rows: u16) -> Vec<String> {
        let fitting = usize::from(rows).saturating_sub(HEADER_HEIGHT + 2) / 2;
        let spinner = self.spinner.current();
        board.runs.iter().take(fitting).map(|run| format_run(run, now_ms, spinner)).collect()
    }

    fn render_lines(&mut self, lines: &[String], cursor: Option<usize>) {
        for (i, line) in lines.iter().enumerate() {
            let selected = cursor == Some(i);
            self.screen.println(&if selected { format!("> {}", lstrip(line)) } else { line.clone() });
            if i + 1 != lines.len() {
                self.screen.println("");
            }
        }
    }
}

fn footer(board: &Board) -> String {
    match confirming(board) {
        Some(run) => format!("  Cancel {} ({})? y / n", run.commit.branch, short_sha(&run.commit.sha)),
        None => "  j/k move   c cancel   q quit".to_string(),
    }
}

fn confirming(board: &Board) -> Option<&Run> {
    board.view.cursor.filter(|_| board.view.confirming).and_then(|index| board.runs.get(index))
}

fn lstrip(line: &str) -> &str {
    line.trim_start_matches([' ', '\t', '\n', '\u{b}', '\u{c}', '\r', '\0'])
}
