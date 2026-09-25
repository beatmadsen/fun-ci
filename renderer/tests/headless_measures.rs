//! The colours, glyphs and measures behind the headless PNGs and stats.json.

use fun_ci_renderer::grid::{Cell, Colour, Emulator};
use fun_ci_renderer::headless::emulate;
use fun_ci_renderer::headless::palette::{cell_colours, hue_sector, luminance};
use fun_ci_renderer::headless::raster::{Image, render};
use fun_ci_renderer::headless::sheet::contact_sheet;
use fun_ci_renderer::headless::stats::stats;
use fun_ci_renderer::replay::TickFrame;

macro_rules! cases {
    ($($name:ident: $actual:expr => $expected:expr;)*) => {
        $(#[test] fn $name() { assert_eq!($actual, $expected); })*
    };
}

fn cell(fg: Colour, attrs: &[&'static str]) -> Cell {
    Cell { text: "x".into(), fg, bg: Colour::Default, attrs: attrs.to_vec() }
}

fn frame(bytes: &str) -> TickFrame {
    TickFrame { size: (4, 2), elapsed_ms: 100, bytes: bytes.as_bytes().to_vec(), showing: "idle".into() }
}

fn screen(bytes: &str) -> Image {
    let mut emulator = Emulator::new((1, 1));
    emulator.feed((1, 1), bytes.as_bytes());
    render(&emulator.grid())
}

fn measured(frames: &[TickFrame]) -> fun_ci_renderer::headless::stats::Stats {
    let grids = emulate(frames);
    let images: Vec<Image> = grids.iter().map(render).collect();
    stats(frames, &grids, &images)
}

cases! {
    white_has_full_luminance: luminance([255, 255, 255]) => 255;
    green_is_brighter_than_blue: luminance([0, 255, 0]) > luminance([0, 0, 255]) => true;
    red_is_hue_sector_zero: hue_sector([255, 0, 0]) => Some(0);
    green_is_hue_sector_four: hue_sector([0, 255, 0]) => Some(4);
    blue_is_hue_sector_eight: hue_sector([0, 0, 255]) => Some(8);
    orange_is_hue_sector_one: hue_sector([255, 135, 0]) => Some(1);
    grey_has_no_hue: hue_sector([128, 128, 128]) => None;
    near_black_has_no_hue: hue_sector([40, 0, 0]) => None;
    the_default_foreground_is_light_grey: cell_colours(&cell(Colour::Default, &[])).0 => [229, 229, 229];
    colour_208_is_xterm_orange: cell_colours(&cell(Colour::Idx(208), &[])).0 => [255, 135, 0];
    colour_236_is_a_dark_grey: cell_colours(&cell(Colour::Idx(236), &[])).0 => [48, 48, 48];
    bold_brightens_a_system_colour: cell_colours(&cell(Colour::Idx(1), &["bold"])).0 => [255, 0, 0];
    bold_leaves_a_256_colour_alone: cell_colours(&cell(Colour::Idx(208), &["bold"])).0 => [255, 135, 0];
    dim_darkens_the_foreground: cell_colours(&cell(Colour::Idx(7), &["dim"])).0 => [142, 142, 142];
    inverse_swaps_foreground_and_background: cell_colours(&cell(Colour::Idx(1), &["inverse"])) => ([0, 0, 0], [205, 0, 0]);
    a_glyph_is_drawn_in_its_foreground: screen("\u{1b}[31m-").pixel(3, 6) => [205, 0, 0];
    a_space_is_all_background: screen(" ").pixel(3, 8) => [0, 0, 0];
    a_braille_dot_is_drawn: screen("\u{2801}").pixel(1, 1) => [229, 229, 229];
    a_missing_braille_dot_is_not: screen("\u{2801}").pixel(5, 1) => [0, 0, 0];
    bold_leaves_a_bright_colour_alone: cell_colours(&cell(Colour::Idx(9), &["bold"])).0 => [255, 0, 0];
    five_frames_tile_three_across: contact_sheet(&vec![Image::blank(4, 2); 5]).width => 6;
    five_frames_tile_two_down: contact_sheet(&vec![Image::blank(4, 2); 5]).height => 2;
    a_square_number_of_frames_tiles_a_square: contact_sheet(&vec![Image::blank(4, 2); 4]).width => 4;
    the_first_frame_counts_the_cells_it_drew: measured(&[frame("ab")]).frames[0].volume.cells_changed => 2;
    a_later_frame_counts_the_cells_that_changed: measured(&[frame("ab"), frame("\u{1b}[Hax")]).frames[1].volume.cells_changed => 1;
    the_longest_row_ends_at_its_last_glyph: measured(&[frame("ab")]).frames[0].volume.longest_row => 2;
    an_empty_screen_is_all_dark: measured(&[frame("")]).frames[0].colour.dark_cell_share.total_cmp(&1.0) => std::cmp::Ordering::Equal;
    two_colours_spread_over_two_hues: measured(&[frame("\u{1b}[31ma\u{1b}[32mb")]).frames[0].colour.hue_spread => 2;
    the_bytes_written_are_counted: measured(&[frame("abc")]).frames[0].volume.bytes => 3;
    frames_are_counted_per_animation_shown: measured(&[frame("a"), frame("b")]).animations["idle"] => 2;
}
