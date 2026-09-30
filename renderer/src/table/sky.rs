//! The night the table sits in (design.md, The console): the header's sky
//! carried on below it, dusky violet under the horizon, deepening over the
//! first rows to the night the rows are read against.

use ratatui::buffer::Buffer;
use ratatui::layout::Rect;
use ratatui::style::Style;
use ratatui::widgets::Widget;

use super::night::{DUSK, NIGHT, blend};
use crate::maths::float;

/// How many rows the dusk takes to deepen to night.
const FALL: usize = 8;

/// The sky behind everything below the header.
#[derive(Debug, Clone, Copy, Default)]
pub struct Sky;

impl Widget for Sky {
    fn render(self, area: Rect, buf: &mut Buffer) {
        for (row, y) in (0..).zip(area.top()..area.bottom()) {
            buf.set_style(Rect { y, height: 1, ..area }, Style::new().bg(shade(row).into()));
        }
    }
}

/// The sky's colour `row` rows below the header: dusk at the top, easing into night.
#[must_use]
pub fn shade(row: usize) -> [u8; 3] {
    let fall = float(row.min(FALL)) / float(FALL);
    blend(DUSK, NIGHT, 1.0 - (1.0 - fall) * (1.0 - fall))
}
