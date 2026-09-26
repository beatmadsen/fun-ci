//! Cells as escape sequences, in 24-bit colour or the nearest of xterm's 256,
//! and only the cells that changed since the last frame.

use fun_ci_renderer::art::cells::Cell;
use fun_ci_renderer::art::output::{Depth, Span, changed_spans, sgr_line};

const RED: [u8; 3] = [255, 0, 0];
const BLUE: [u8; 3] = [0, 0, 255];

fn block(fg: [u8; 3], bg: [u8; 3]) -> Cell {
    Cell { glyph: '▄', fg, bg }
}

fn space(bg: [u8; 3]) -> Cell {
    Cell { glyph: ' ', fg: bg, bg }
}

#[test]
fn should_set_both_colours_in_24_bit_before_a_glyph() {
    assert_eq!(sgr_line(&[block(RED, BLUE)], Depth::TrueColour), "\u{1b}[38;2;255;0;0m\u{1b}[48;2;0;0;255m▄\u{1b}[0m");
}

#[test]
fn should_not_repeat_a_colour_when_the_next_cell_keeps_it() {
    assert_eq!(sgr_line(&[space(RED), space(RED)], Depth::TrueColour), "\u{1b}[48;2;255;0;0m  \u{1b}[0m");
}

#[test]
fn should_set_only_the_background_when_the_cell_is_a_space() {
    assert_eq!(sgr_line(&[space(BLUE)], Depth::TrueColour), "\u{1b}[48;2;0;0;255m \u{1b}[0m");
}

#[test]
fn should_use_the_nearest_colour_of_the_xterm_cube_when_limited_to_256() {
    assert_eq!(sgr_line(&[block(RED, [0, 0, 250])], Depth::Xterm256), "\u{1b}[38;5;196m\u{1b}[48;5;21m▄\u{1b}[0m");
}

#[test]
fn should_use_the_nearest_grey_when_it_is_closer_than_the_cube() {
    assert_eq!(sgr_line(&[space([128, 128, 128])], Depth::Xterm256), "\u{1b}[48;5;244m \u{1b}[0m");
}

#[test]
fn should_redraw_every_row_when_there_is_no_previous_frame() {
    let now = vec![vec![space(RED)], vec![space(BLUE)]];
    assert_eq!(changed_spans(None, &now), [Span { row: 0, col: 0, len: 1 }, Span { row: 1, col: 0, len: 1 }]);
}

#[test]
fn should_redraw_nothing_when_no_cell_changed() {
    let now = vec![vec![space(RED), space(BLUE)]];
    assert_eq!(changed_spans(Some(&now), &now), []);
}

#[test]
fn should_redraw_changed_cells_as_one_run_when_single_unchanged_cells_part_them() {
    let before = vec![vec![space(RED); 5]];
    let now = vec![vec![space(RED), space(BLUE), space(RED), space(BLUE), space(RED)]];
    assert_eq!(changed_spans(Some(&before), &now), [Span { row: 0, col: 1, len: 3 }]);
}

#[test]
fn should_redraw_changed_cells_as_separate_runs_when_two_unchanged_cells_part_them() {
    let before = vec![vec![space(RED); 6]];
    let now = vec![vec![space(RED), space(BLUE), space(RED), space(RED), space(BLUE), space(RED)]];
    assert_eq!(changed_spans(Some(&before), &now), [Span { row: 0, col: 1, len: 1 }, Span { row: 0, col: 4, len: 1 }]);
}

#[test]
fn should_redraw_everything_when_the_previous_frame_was_another_size() {
    let before = vec![vec![space(RED)]];
    let now = vec![vec![space(RED), space(RED)]];
    assert_eq!(changed_spans(Some(&before), &now), [Span { row: 0, col: 0, len: 2 }]);
}
