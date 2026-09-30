//! Colours in the depth the terminal has: 24-bit as they are, or the nearest
//! of xterm's 256, from the colour cube or the grey ramp.

use fun_ci_renderer::output::depth::{Depth, escape, xterm};

#[test]
fn a_colour_is_written_as_it_is_in_24_bit() {
    assert_eq!(escape(38, [255, 0, 0], Depth::TrueColour), "\u{1b}[38;2;255;0;0m");
}

#[test]
fn a_colour_is_written_as_its_nearest_of_256_where_that_is_all_there_is() {
    assert_eq!(escape(48, [0, 0, 250], Depth::Xterm256), "\u{1b}[48;5;21m");
}

#[test]
fn pure_green_is_the_cube_s_green() {
    assert_eq!(xterm([0, 255, 0]), 46);
}

#[test]
fn a_near_black_is_the_cube_s_black() {
    assert_eq!(xterm([2, 0, 10]), 16);
}

#[test]
fn a_mid_grey_is_from_the_grey_ramp() {
    assert_eq!(xterm([128, 128, 128]), 244);
}
