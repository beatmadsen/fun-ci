//! The table of runs under the header (design.md, The console): a faint line
//! naming the stages, then one line per run, laid out in columns that hold
//! from 60 columns up (`layout`), and drawn cell by cell (`line`) so no line
//! is ever wider than the terminal.

pub mod layout;
pub mod line;
pub mod palette;
pub mod row;
pub mod stage_cell;
pub mod tone;

use crate::art::output::Depth;
use crate::model::Board;
use layout::{Layout, STAGES};
use line::{Line, Style};
use row::{Place, run_line};
use tone::newest_of_branch;

/// What a frame draws with: the board's clock, the animation clock, the
/// spinner's frame, the terminal's width and colours.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Frame {
    pub now_ms: i64,
    pub play_ms: u64,
    pub spinner: char,
    pub width: u16,
    pub depth: Depth,
}

/// The table's lines, the stages' names first, and the layout they share.
#[derive(Debug, Clone)]
pub struct Drawn {
    pub lines: Vec<String>,
    pub layout: Layout,
}

#[must_use]
pub fn draw(board: &Board, frame: Frame) -> Drawn {
    let layout = Layout::fit(&board.runs, frame.width);
    let newest = newest_of_branch(&board.runs);
    let place = |i: usize| Place { newest: newest[i], selected: board.view.cursor == Some(i) };
    let rows = board.runs.iter().enumerate().map(|(i, run)| run_line(run, &layout, place(i), frame).encode(frame.depth));
    let lines = std::iter::once(heading(&layout).encode(frame.depth)).chain(rows).collect();
    Drawn { lines, layout }
}

/// The stages' names over their cells, or their initials when cells hold only a mark.
fn heading(layout: &Layout) -> Line {
    let mut line = Line::new(layout.width, None);
    for stage in STAGES {
        let name: String = stage.chars().take(if layout.times { stage.len() } else { 1 }).collect();
        line.put(layout.stage_column(stage).unwrap_or_default(), &name, Style::plain(palette::FAINT));
    }
    line
}
