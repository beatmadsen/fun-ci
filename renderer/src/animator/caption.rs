//! The streak, written over the header's picture (acceptance-tests.md,
//! AT-7.6): how many runs in a row have passed, in green, or that the
//! streak is broken, in plain white, never alarming.

use crate::art::cells::Cell;

const GREEN: [u8; 3] = [90, 230, 120];
const WHITE: [u8; 3] = [225, 225, 225];
/// The header row the streak sits on, and the columns kept clear to its right.
const ROW: usize = 1;
const MARGIN: usize = 2;

/// The words for `streak` and their colour; none before there is a streak.
#[must_use]
pub fn caption(streak: Option<u32>) -> Option<(String, [u8; 3])> {
    match streak? {
        0 => Some(("streak broken".to_string(), WHITE)),
        n => Some((format!("{n} in a row!"), GREEN)),
    }
}

/// Writes `words` in `colour` into `cells`, ending `MARGIN` columns from the
/// right, over the picture darkened behind each letter so it stays legible.
pub fn stamp(cells: &mut [Vec<Cell>], (words, colour): &(String, [u8; 3])) {
    let Some(row) = cells.get_mut(ROW) else { return };
    let start = row.len().saturating_sub(MARGIN + words.chars().count());
    for (cell, glyph) in row.iter_mut().skip(start).zip(words.chars()) {
        *cell = Cell { glyph, fg: *colour, bg: cell.bg.map(|channel| channel / 3) };
    }
}
