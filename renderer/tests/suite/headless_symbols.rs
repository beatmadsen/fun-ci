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
    the_diamond_is_drawn: "◆";
    the_hollow_diamond_is_drawn: "◇";
    the_hollow_circle_is_drawn: "◌";
    the_ellipsis_is_drawn: "…";
    the_dash_is_drawn: "–";
    the_dot_is_drawn: "·";
    the_firefly_is_drawn: "•";
    the_block_s_top_edge_is_drawn: "▄";
    the_block_s_bottom_edge_is_drawn: "▀";
}

#[test]
fn an_italic_cell_is_drawn_slanted() {
    let italic = Cell { text: "l".into(), fg: Colour::Default, bg: Colour::Default, attrs: vec!["italic"] };
    let slanted = render(&Grid { cols: 1, rows: 1, cells: vec![vec![italic]] }).pixels;

    assert_ne!(slanted, drawn("l"));
}
