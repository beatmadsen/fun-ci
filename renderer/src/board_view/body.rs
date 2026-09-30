//! Everything below the header: the table, blank lines down to the footer,
//! the stale trunks' note when the table had to go flat, and the footer on
//! the last line; or, with no runs, how to get some.

use ratatui::buffer::Buffer;
use ratatui::layout::{Constraint, Layout, Rect};
use ratatui::style::Stylize;
use ratatui::text::{Line, Text};
use ratatui::widgets::Widget;

use crate::animator::{HEADER_HEIGHT, Places};
use crate::model::Board;
use crate::table::footer::footer_line;
use crate::table::page::page;
use crate::table::sheet::Sheet;
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

/// The blank line between the table and the footer.
const UNDER_TABLE: usize = 1;

/// Draws what goes below the header into `buf`, and says where the effects land.
pub fn body(buf: &mut Buffer, board: &Board, frame: Frame) -> Places {
    if board.runs.is_empty() {
        empty(buf);
        return Places::default();
    }
    rows(buf, board, frame)
}

/// The empty state's lines, as many as fit below the header.
fn empty(buf: &mut Buffer) {
    let lines = EMPTY_STATE.into_iter().map(Line::from).chain([Line::from("  q quit".dim())]);
    Text::from_iter(lines).render(below_header(buf.area), buf);
}

/// The table and its page down to the footer, and the footer on the last line.
fn rows(buf: &mut Buffer, board: &Board, frame: Frame) -> Places {
    let [sheet, footer] = Layout::vertical([Constraint::Fill(1), Constraint::Length(1)]).areas(below_header(buf.area));
    let drawn = draw(board, frame, usize::from(sheet.height).saturating_sub(UNDER_TABLE));
    let body = page(board, &drawn, frame, usize::from(sheet.height));
    Sheet { lines: &body, paper: drawn.paper }.render(sheet, buf);
    footer_line(board, &drawn, frame).render(footer, buf);
    places(&drawn, body.len())
}

/// What of `area` is below the header.
fn below_header(area: Rect) -> Rect {
    let header = u16::try_from(HEADER_HEIGHT).unwrap_or(u16::MAX);
    let [_, below] = Layout::vertical([Constraint::Length(header), Constraint::Fill(1)]).areas(area);
    below
}

/// Where the table's rows and marks landed, for the stage effects, and the
/// line under the table for an effect's banner.
fn places(drawn: &Drawn, body: usize) -> Places {
    let rows = drawn.rows.iter().map(|(run, line)| (*run, HEADER_HEIGHT + line)).collect();
    Places { rows, strip: drawn.columns.strip, banner: Some(HEADER_HEIGHT + drawn.lines.len().min(body)) }
}
