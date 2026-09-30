//! Everything below the header: the table, blank lines down to the footer,
//! the stale trunks' note when the table had to go flat, and the footer on
//! the last line; or, with no runs, how to get some.

use ratatui::buffer::Buffer;
use ratatui::layout::Rect;
use ratatui::style::{Modifier, Style};
use ratatui::widgets::Widget;

use crate::animator::{HEADER_HEIGHT, Places};
use crate::model::Board;
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

/// The footer and the blank line above it.
const BELOW_TABLE: usize = 2;

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
    let fitting = usize::from(buf.area.height).saturating_sub(HEADER_HEIGHT);
    let lines = EMPTY_STATE.iter().map(|text| (*text, Style::default())).chain([("  q quit", Style::default().add_modifier(Modifier::DIM))]);
    for (y, (text, style)) in (HEADER_HEIGHT..).zip(lines.take(fitting)) {
        let at = line_at(buf.area, y);
        buf.set_stringn(at.x, at.y, text, usize::from(at.width), style);
    }
}

/// The table and its page down to the footer, and the footer on the last line.
fn rows(buf: &mut Buffer, board: &Board, frame: Frame) -> Places {
    let height = usize::from(buf.area.height).saturating_sub(HEADER_HEIGHT);
    let drawn = draw(board, frame, height.saturating_sub(BELOW_TABLE));
    let body = page(board, &drawn, frame, height.saturating_sub(1));
    for (y, line) in (HEADER_HEIGHT..).zip(&body) {
        line.render(line_at(buf.area, y), buf);
    }
    if let Some(last) = (HEADER_HEIGHT..usize::from(buf.area.height)).last() {
        footer_line(board, &drawn, frame).render(line_at(buf.area, last), buf);
    }
    places(&drawn, body.len())
}

/// Line `y` of `area`, from 0.
fn line_at(area: Rect, y: usize) -> Rect {
    Rect::new(area.x, area.y.saturating_add(u16::try_from(y).unwrap_or(u16::MAX)), area.width, 1).intersection(area)
}

/// Where the table's rows and marks landed, for the stage effects, and the
/// line under the table for an effect's banner.
fn places(drawn: &Drawn, body: usize) -> Places {
    let rows = drawn.rows.iter().map(|(run, line)| (*run, HEADER_HEIGHT + line)).collect();
    Places { rows, strip: drawn.columns.strip, banner: Some(HEADER_HEIGHT + drawn.lines.len().min(body)) }
}
