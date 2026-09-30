//! What goes below the header down to the footer: the table, blank lines,
//! the stale trunks' note when the table had to go flat, and on a still
//! board the firefly in the open space.

use super::firefly::{line, mote, still};
use ratatui::text::Line;

use super::line::placed;
use super::night::{NOTE, ink};
use super::{Drawn, Frame};
use crate::model::Board;

/// The page of `lines` lines below the header for `board`, drawn as `drawn`.
#[must_use]
pub fn page(board: &Board, drawn: &Drawn, frame: Frame, lines: usize) -> Vec<Line<'static>> {
    let mut page = body(drawn, lines);
    if still(board) {
        firefly(&mut page, drawn.lines.len(), frame);
    }
    page
}

/// The table's lines, padded with blank ones to `lines`; when the table
/// carries the stale trunks' note, it comes last, a blank line under it.
fn body(drawn: &Drawn, lines: usize) -> Vec<Line<'static>> {
    let mut body: Vec<Line<'static>> = drawn.lines.iter().take(lines).cloned().collect();
    let note = drawn.note.as_ref().map(|note| note_line(note, drawn));
    let blanks = lines.saturating_sub(body.len() + usize::from(note.is_some()));
    let under_note = usize::from(note.is_some() && blanks > 0);
    body.extend(std::iter::repeat_n(Line::default(), blanks - under_note).chain(note));
    body.extend(std::iter::repeat_n(Line::default(), under_note));
    body
}

/// The firefly on one of the open lines between the table, a line after it,
/// and the line above the footer.
fn firefly(body: &mut [Line<'static>], table: usize, frame: Frame) {
    let open: Vec<usize> = (table + 1..body.len().saturating_sub(1)).filter(|&at| body[at].width() == 0).collect();
    if let Some(at) = line(&open, frame.play_ms) {
        let spot = mote(frame.width, frame.play_ms);
        body[at] = placed(vec![(spot.column, "•".to_string(), ink(spot.colour))]);
    }
}

/// The stale trunks' note in italics where the labels would be.
fn note_line(note: &str, drawn: &Drawn) -> Line<'static> {
    placed(vec![(drawn.columns.label, note.to_string(), ink(NOTE).italic())])
}
