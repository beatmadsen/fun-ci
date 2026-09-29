//! The status board: header space, one row per run, footer, and the
//! animations over them, laid out as the 1.x `BoardRenderer` laid them out.

use crate::animator::{Animator, HEADER_HEIGHT};
use crate::ansi::{DIM, RESET, paint};
use crate::art::output::{Depth, escape};
use crate::format::{age, cut, project_name, short_sha};
use crate::model::{Board, Run, StaleTrunk};
use crate::screen::Screen;
use crate::spinner::Spinner;
use crate::table::layout::conflict_marker;
use crate::table::palette::SECONDARY;
use crate::table::{Frame, draw};

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

/// The rows under the header that are not runs: a blank line, the stages'
/// names, a blank line and the footer (renderer-protocol.md, `board`).
const CHROME_BELOW_HEADER: usize = 4;

/// What the footer adds when a conflict is shown as `↯ main` rather than in words.
const ZIGZAG_LEGEND: &str = "   ↯ conflicts with trunk";

/// Draws boards into a frame buffer.
#[derive(Debug)]
pub struct BoardView {
    screen: Screen,
    spinner: Spinner,
    animator: Animator,
    depth: Depth,
}

impl BoardView {
    #[must_use]
    pub fn new(animator: Animator) -> Self {
        Self { screen: Screen::new(80), spinner: Spinner::default(), animator, depth: Depth::TrueColour }
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

    /// A blank line, the stages' names, one line per run that fits, a blank
    /// line, and the footer on the line after.
    fn render_rows(&mut self, board: &Board, at: Moment, rows: u16) {
        let (lines, zigzag) = self.lines(board, at, rows);
        if !lines.is_empty() {
            self.screen.println("");
            for line in &lines {
                self.screen.println(line);
            }
            self.screen.println("");
        }
        let (keys, note) = footer(board, at.board_ms);
        self.render_footer(&keys, &(if zigzag { ZIGZAG_LEGEND } else { "" }.to_string() + &note), rows);
    }

    /// The footer below the header, if a row is left for it: the keys dim, and
    /// the notes in a grey no state uses, cut first when they don't fit.
    fn render_footer(&mut self, keys: &str, note: &str, rows: u16) {
        if usize::from(rows) > HEADER_HEIGHT + 1 {
            let width = usize::from(self.screen.width());
            let keys = cut(keys, width);
            let note = cut(note, width - keys.chars().count());
            let note_colour = escape(38, SECONDARY, self.depth);
            self.screen.print_last(&format!("{}{note_colour}{note}{RESET}", paint(DIM, &keys)));
        }
    }

    /// The table's heading and as many runs as fit, or nothing when not even
    /// one does; and whether a conflict among them is shown as a zigzag.
    fn lines(&self, board: &Board, at: Moment, rows: u16) -> (Vec<String>, bool) {
        let fitting = usize::from(rows).saturating_sub(HEADER_HEIGHT + CHROME_BELOW_HEADER);
        let frame = Frame { now_ms: at.board_ms, play_ms: at.play_ms, spinner: self.spinner.current(), width: self.screen.width(), depth: self.depth };
        let drawn = draw(board, frame);
        let zigzag = !drawn.layout.words && board.runs.iter().take(fitting).any(|run| conflict_marker(run, false).is_some());
        (if fitting == 0 { Vec::new() } else { drawn.lines.into_iter().take(fitting + 1).collect() }, zigzag)
    }

}

/// The footer's keys or prompt, and its note on stale trunks.
fn footer(board: &Board, now_ms: i64) -> (String, String) {
    match confirming(board) {
        Some(run) => (format!("  Cancel {} ({})? y / n", run.commit.branch, short_sha(&run.commit.sha)), String::new()),
        None => ("  j/k move   c cancel   q quit".to_string(), stale_note(&board.stale_trunks, now_ms)),
    }
}

/// Which projects' trunks are stale, said once here rather than on every row.
fn stale_note(stale: &[StaleTrunk], now_ms: i64) -> String {
    if stale.is_empty() {
        return String::new();
    }
    let projects: Vec<String> = stale.iter().map(|trunk| stale_project(trunk, now_ms)).collect();
    format!("   {}", projects.join("; "))
}

/// `app: trunk 3h old`, from its last good fetch, or `app: trunk fetch failed`.
fn stale_project(trunk: &StaleTrunk, now_ms: i64) -> String {
    let fetched = trunk.since.map_or_else(|| "fetch failed".to_string(), |since| format!("{} old", age(since, now_ms)));
    format!("{}: trunk {fetched}", project_name(&trunk.project))
}

fn confirming(board: &Board) -> Option<&Run> {
    board.view.cursor.filter(|_| board.view.confirming).and_then(|index| board.runs.get(index))
}
