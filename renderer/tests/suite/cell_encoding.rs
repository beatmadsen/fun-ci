//! A canvas becomes terminal cells: each cell is 4x8 pixels, sampled at 2x4
//! points and drawn as the quadrant glyph or braille dots, in two colours,
//! that come closest to the samples.

use fun_ci_renderer::art::canvas::Canvas;
use fun_ci_renderer::art::cells::{Cell, encode};

const RED: [f64; 3] = [1.0, 0.0, 0.0];
const BLUE: [f64; 3] = [0.0, 0.0, 1.0];
const WHITE: [f64; 3] = [1.0, 1.0, 1.0];

fn red_cell() -> Canvas {
    let mut canvas = Canvas::new(4, 8);
    canvas.fill_rect((0, 0), (4, 8), RED);
    canvas
}

fn first_cell(canvas: &Canvas) -> Cell {
    encode(canvas)[0][0]
}

#[test]
fn should_draw_a_space_in_the_background_colour_when_the_cell_is_one_colour() {
    assert_eq!(first_cell(&red_cell()), Cell { glyph: ' ', fg: [255, 0, 0], bg: [255, 0, 0] });
}

#[test]
fn should_draw_a_right_half_block_when_the_left_and_right_halves_differ() {
    let mut canvas = red_cell();
    canvas.fill_rect((2, 0), (2, 8), BLUE);
    assert_eq!(first_cell(&canvas), Cell { glyph: '▐', fg: [0, 0, 255], bg: [255, 0, 0] });
}

#[test]
fn should_draw_a_lower_half_block_when_the_top_and_bottom_halves_differ() {
    let mut canvas = red_cell();
    canvas.fill_rect((0, 4), (4, 4), BLUE);
    assert_eq!(first_cell(&canvas).glyph, '▄');
}

#[test]
fn should_draw_a_diagonal_when_opposite_corners_match() {
    let mut canvas = red_cell();
    canvas.fill_rect((2, 0), (2, 4), BLUE);
    canvas.fill_rect((0, 4), (2, 4), BLUE);
    assert_eq!(first_cell(&canvas).glyph, '▞');
}

#[test]
fn should_draw_a_lone_quadrant_when_one_corner_differs() {
    let mut canvas = red_cell();
    canvas.fill_rect((2, 4), (2, 4), BLUE);
    assert_eq!(first_cell(&canvas).glyph, '▗');
}

#[test]
fn should_split_where_the_error_is_least_when_a_cell_has_more_than_two_colours() {
    let mut canvas = red_cell();
    canvas.fill_rect((0, 4), (2, 4), BLUE);
    canvas.fill_rect((2, 4), (2, 4), [0.0, 0.0, 0.6]);
    assert_eq!(first_cell(&canvas), Cell { glyph: '▄', fg: [0, 0, 204], bg: [255, 0, 0] });
}

#[test]
fn should_colour_a_quadrant_with_the_mean_of_its_pixels_when_they_differ() {
    let mut canvas = Canvas::new(4, 8);
    canvas.fill_rect((0, 0), (1, 8), WHITE);
    assert_eq!(first_cell(&canvas).bg, [128, 128, 128]);
}

#[test]
fn should_lay_out_one_cell_per_four_by_eight_pixels() {
    let cells = encode(&Canvas::new(12, 16));
    assert_eq!((cells.len(), cells[0].len()), (2, 3));
}

#[test]
fn should_draw_a_braille_dot_when_a_dim_point_of_light_lies_on_a_dark_cell() {
    let mut canvas = Canvas::new(4, 8);
    canvas.fill_rect((2, 4), (2, 2), [0.25; 3]);
    assert_eq!(first_cell(&canvas), Cell { glyph: '⠠', fg: [255, 255, 255], bg: [0, 0, 0] });
}

#[test]
fn should_draw_two_braille_dots_when_two_dim_points_of_light_lie_on_a_dark_cell() {
    let mut canvas = Canvas::new(4, 8);
    canvas.fill_rect((0, 0), (2, 2), [0.25; 3]);
    canvas.fill_rect((2, 6), (2, 2), [0.25; 3]);
    assert_eq!(first_cell(&canvas).glyph, '⢁');
}

#[test]
fn should_draw_a_lower_quarter_block_when_an_edge_lies_a_quarter_up_the_cell() {
    let mut canvas = red_cell();
    canvas.fill_rect((0, 6), (4, 2), BLUE);
    assert_eq!(first_cell(&canvas), Cell { glyph: '▂', fg: [0, 0, 255], bg: [255, 0, 0] });
}

#[test]
fn should_draw_a_lower_three_quarter_block_when_an_edge_lies_a_quarter_down_the_cell() {
    let mut canvas = red_cell();
    canvas.fill_rect((0, 2), (4, 6), BLUE);
    assert_eq!(first_cell(&canvas).glyph, '▆');
}
