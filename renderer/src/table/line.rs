//! One line of the table as a ratatui `Line`: each part's text from the
//! column it starts at, or straight after the part before it if that runs
//! past the column. ratatui cuts the line where its area ends, so a line can
//! never wrap: a line that wrapped would push the whole board up.

use ratatui::style::Style;
use ratatui::text::{Line, Span};
use unicode_width::UnicodeWidthStr;

/// A part of a line: where it starts, what it says and how.
pub type Part = (usize, String, Style);

/// `parts` left to right, each at its column, spaced with blank spans.
#[must_use]
pub fn placed(mut parts: Vec<Part>) -> Line<'static> {
    parts.sort_by_key(|part| part.0);
    let mut next = 0;
    let spans = parts.into_iter().flat_map(|(at, text, style)| {
        let gap = at.saturating_sub(next);
        next += gap + text.width();
        [Span::raw(" ".repeat(gap)), Span::styled(text, style)]
    });
    spans.filter(|span| !span.content.is_empty()).collect()
}
