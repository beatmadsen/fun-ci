//! What goes below the header down to the footer: the table, blank lines,
//! the stale trunks' note when the table had to go flat, and on a still
//! board the firefly in the open space.

use super::firefly::{line, mote, still};
use super::line::{Line, Style};
use super::night::NOTE;
use super::{Drawn, Frame};
use crate::model::Board;

/// The page of `lines` lines below the header for `board`, drawn as `drawn`.
#[must_use]
pub fn page(board: &Board, drawn: &Drawn, frame: Frame, lines: usize) -> Vec<String> {
    let mut page = body(drawn, frame, lines);
    if still(board) {
        firefly(&mut page, drawn.lines.len(), frame);
    }
    page
}

/// The table's lines, padded with blank ones to `lines`; when the table
/// carries the stale trunks' note, it comes last, a blank line under it.
fn body(drawn: &Drawn, frame: Frame, lines: usize) -> Vec<String> {
    let mut body: Vec<String> = drawn.lines.iter().take(lines).cloned().collect();
    let note = drawn.note.as_ref().map(|note| note_line(note, drawn, frame));
    let blanks = lines.saturating_sub(body.len() + usize::from(note.is_some()));
    let under_note = usize::from(note.is_some() && blanks > 0);
    body.extend(std::iter::repeat_n(String::new(), blanks - under_note).chain(note));
    body.extend(std::iter::repeat_n(String::new(), under_note));
    body
}

/// The firefly on one of the open lines between the table, a line after it,
/// and the line above the footer.
fn firefly(body: &mut [String], table: usize, frame: Frame) {
    let open: Vec<usize> = (table + 1..body.len().saturating_sub(1)).filter(|&at| body[at].is_empty()).collect();
    if let Some(at) = line(&open, frame.play_ms) {
        let spot = mote(frame.width, frame.play_ms);
        let mut drawn = Line::new(usize::from(frame.width), None);
        drawn.put(spot.column, "•", Style::plain(spot.colour));
        body[at] = drawn.encode(frame.depth);
    }
}

/// The stale trunks' note in italics where the labels would be.
fn note_line(note: &str, drawn: &Drawn, frame: Frame) -> String {
    let mut line = Line::new(usize::from(frame.width), None);
    line.put(drawn.columns.label, note, Style::italic(NOTE));
    line.encode(frame.depth)
}
