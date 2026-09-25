//! Where glyphs, braille dots and contact-sheet tiles land in the pixels.

use fun_ci_renderer::grid::Emulator;
use fun_ci_renderer::headless::raster::{Image, render};
use fun_ci_renderer::headless::sheet::contact_sheet;

const LIT: [u8; 3] = [229, 229, 229];
const DARK: [u8; 3] = [0, 0, 0];

macro_rules! cases {
    ($($name:ident: $actual:expr => $expected:expr;)*) => {
        $(#[test] fn $name() { assert_eq!($actual, $expected); })*
    };
}

/// A 2x2 terminal after `bytes`, as pixels.
fn screen(bytes: &str) -> Image {
    let mut emulator = Emulator::new((2, 2));
    emulator.feed((2, 2), bytes.as_bytes());
    render(&emulator.grid())
}

/// `count` frames of `width` x `height`, frame k marked [k, 0, 0] at `mark`.
fn marked_frames(count: u8, (width, height): (usize, usize), mark: (usize, usize)) -> Vec<Image> {
    let frame = |k: u8| {
        let mut image = Image::blank(width, height);
        image.set(mark.0, mark.1, [k, 0, 0]);
        image
    };
    (0..count).map(frame).collect()
}

cases! {
    a_glyph_in_the_second_column_starts_eight_pixels_in: screen("a-").pixel(8 + 3, 6) => LIT;
    a_glyph_in_the_second_row_starts_sixteen_pixels_down: screen("a\r\n-").pixel(3, 16 + 6) => LIT;
    dot_one_fills_two_by_two_pixels: screen("\u{2801}").pixel(2, 2) => LIT;
    dot_one_leaves_the_row_below_it_dark: screen("\u{2801}").pixel(1, 3) => DARK;
    dot_one_leaves_the_right_column_dark: screen("\u{2801}").pixel(5, 1) => DARK;
    dot_four_is_the_top_of_the_right_column: screen("\u{2808}").pixel(5, 1) => LIT;
    dot_four_leaves_the_left_column_dark: screen("\u{2808}").pixel(1, 1) => DARK;
    dot_five_is_the_second_dot_of_the_right_column: screen("\u{2810}").pixel(5, 5) => LIT;
    dot_seven_is_the_bottom_of_the_left_column: screen("\u{2840}").pixel(1, 13) => LIT;
    dots_one_and_four_light_both_columns: (screen("\u{2809}").pixel(1, 1), screen("\u{2809}").pixel(6, 2)) => (LIT, LIT);
    the_second_tile_sits_right_of_the_first: contact_sheet(&marked_frames(4, (4, 2), (0, 0))).pixel(2, 0) => [1, 0, 0];
    the_third_tile_starts_the_second_row: contact_sheet(&marked_frames(4, (4, 2), (0, 0))).pixel(0, 1) => [2, 0, 0];
    the_fourth_tile_ends_the_second_row: contact_sheet(&marked_frames(4, (4, 2), (0, 0))).pixel(2, 1) => [3, 0, 0];
    a_second_row_tile_starts_one_tile_height_down: contact_sheet(&marked_frames(4, (4, 4), (0, 0))).pixel(0, 2) => [2, 0, 0];
    five_tall_frames_make_a_sheet_two_tiles_high: contact_sheet(&vec![Image::blank(4, 4); 5]).height => 4;
    a_tile_keeps_the_sampled_pixel: contact_sheet(&marked_frames(2, (4, 4), (2, 2))).pixel(2 + 1, 1) => [1, 0, 0];
}
