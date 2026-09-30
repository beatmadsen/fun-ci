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

/// The leftmost lit pixel on pixel row `y` of a one-cell image, if any.
fn leftmost(pixels: &[u8], y: usize) -> Option<usize> {
    let background = &pixels[..3];
    (0..8).find(|x| &pixels[(y * 8 + x) * 3..(y * 8 + x) * 3 + 3] != background)
}

fn italic(text: &str) -> Vec<u8> {
    let cell = Cell { text: text.to_string(), fg: Colour::Default, bg: Colour::Default, attrs: vec!["italic"] };
    render(&Grid { cols: 1, rows: 1, cells: vec![vec![cell]] }).pixels
}

#[test]
fn an_italic_cell_leans_two_pixels_right_at_the_top_one_in_the_middle_and_none_at_the_foot() {
    let (upright, leaning) = (drawn("l"), italic("l"));
    let lean = |y: usize| leftmost(&leaning, y).zip(leftmost(&upright, y)).map(|(a, b)| a - b);

    assert_eq!([lean(2), lean(8), lean(12)], [Some(2), Some(1), Some(0)]);
}

#[test]
fn an_italic_cell_is_drawn_slanted() {
    let italic = Cell { text: "l".into(), fg: Colour::Default, bg: Colour::Default, attrs: vec!["italic"] };
    let slanted = render(&Grid { cols: 1, rows: 1, cells: vec![vec![italic]] }).pixels;

    assert_ne!(slanted, drawn("l"));
}
