//! The headless PNGs draw every mark the table uses, rather than the box a
//! glyph the font lacks comes out as: the evaluator judges the PNGs, and a
//! box would hide the very state the mark stands for.

use fun_ci_renderer::grid::{Cell, Colour, Grid};
use fun_ci_renderer::headless::raster::render;

/// The pixels of `text` alone in a one-cell grid.
fn drawn(text: &str) -> Vec<u8> {
    let cell = Cell { text: text.to_string(), fg: Colour::Default, bg: Colour::Default, attrs: vec![] };
    render(&Grid { cols: 1, rows: 1, cells: vec![vec![cell]] }).pixels
}

macro_rules! marks {
    ($($test:ident: $mark:literal;)*) => {
        $(
            #[test]
            fn $test() {
                assert_ne!(drawn($mark), drawn("\u{E000}"));
            }
        )*
    };
}

marks! {
    the_tick_is_drawn: "✓";
    the_cross_is_drawn: "✗";
    the_warning_triangle_is_drawn: "▲";
    the_hollow_circle_is_drawn: "◌";
    the_conflict_zigzag_is_drawn: "↯";
    the_cursor_mark_is_drawn: "❯";
    the_ellipsis_is_drawn: "…";
    the_dash_is_drawn: "–";
    the_dot_is_drawn: "·";
}
