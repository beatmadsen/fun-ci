//! Everything below the header: the table, blank lines down to the footer,
//! the stale trunks' note when the table had to go flat, and the footer on
//! the last line; or, with no runs, how to get some.

use ratatui::buffer::Buffer;
use ratatui::layout::{Constraint, Layout, Rect};
use ratatui::text::{Line, Text};
use ratatui::widgets::Widget;

use crate::animator::{HEADER_HEIGHT, Places};
use crate::model::Board;
use crate::table::footer::{Offer, QUIT, footer_line, offered};
use crate::table::line::placed;
use crate::table::night::{CAP, CURSOR, KEY, LABEL, NOTE, ink};
use crate::table::page::page;
use crate::table::sheet::Sheet;
use crate::table::sky::Sky;
use crate::table::{Drawn, Frame, draw};

/// Where the empty state's words start, and where what they say starts.
const WORDS: usize = 10;
const SAYS: usize = 24;

/// The blank line between the table and the footer.
const UNDER_TABLE: usize = 1;

/// Draws what goes below the header into `buf`, and says where the effects land.
pub fn body(buf: &mut Buffer, board: &Board, frame: Frame) -> Places {
    Sky.render(below_header(buf.area), buf);
    if board.runs.is_empty() {
        empty(buf);
        return Places::default();
    }
    rows(buf, board, frame)
}

/// The empty state's lines, as many as fit below the header: what to do,
/// the command on a cap, and the quit key.
fn empty(buf: &mut Buffer) {
    let (quit, _) = offered(&Offer { question: None, keys: vec![QUIT] }, 2);
    let lines = [
        Line::default(),
        Line::default(),
        placed(vec![(WORDS, "No runs yet.".into(), ink(CURSOR).bold())]),
        Line::default(),
        placed(vec![(WORDS, "Set it up".into(), ink(LABEL)), (SAYS, " fun-ci init --everything ".into(), ink(KEY).bg(CAP.into()))]),
        placed(vec![(WORDS, "Then commit".into(), ink(LABEL)), (SAYS + 1, "each commit starts a run".into(), ink(NOTE).italic())]),
        Line::default(),
        placed(quit),
    ];
    Text::from_iter(lines).render(below_header(buf.area), buf);
}

/// The table and its page down to the footer, and the footer on the last line.
fn rows(buf: &mut Buffer, board: &Board, frame: Frame) -> Places {
    let [sheet, footer] = Layout::vertical([Constraint::Fill(1), Constraint::Length(1)]).areas(below_header(buf.area));
    let drawn = draw(board, frame, usize::from(sheet.height).saturating_sub(UNDER_TABLE));
    let body = page(board, &drawn, frame, usize::from(sheet.height));
    Sheet { lines: &body, paper: drawn.paper, leaders: drawn.leaders.clone() }.render(sheet, buf);
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
    let span = (drawn.columns.margin, drawn.columns.age_end + 2);
    Places { rows, strip: drawn.columns.strip, span, banner: Some(HEADER_HEIGHT + drawn.lines.len().min(body)) }
}
