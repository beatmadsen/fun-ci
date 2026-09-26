//! A canvas starts black and takes light only on its own pixels.

use fun_ci_renderer::art::canvas::Canvas;

use crate::support::shades::rgb;

const RED: [f64; 3] = [1.0, 0.0, 0.0];

#[test]
fn should_start_black() {
    assert_eq!(rgb(Canvas::new(2, 2).get(1, 1)), [0, 0, 0]);
}

#[test]
fn should_add_light_to_the_pixel_it_is_given() {
    let mut canvas = Canvas::new(2, 2);
    canvas.add((1, 0), RED);
    assert_eq!(rgb(canvas.get(1, 0)), [255, 0, 0]);
}

#[test]
fn should_not_wrap_light_added_just_past_the_right_edge_onto_the_next_row() {
    let mut canvas = Canvas::new(2, 2);
    canvas.add((2, 0), RED);
    assert_eq!(rgb(canvas.get(0, 1)), [0, 0, 0]);
}

#[test]
fn should_ignore_light_added_just_below_the_bottom_edge() {
    let mut canvas = Canvas::new(2, 2);
    canvas.add((0, 2), RED);
    assert_eq!(canvas, Canvas::new(2, 2));
}

#[test]
fn should_ignore_light_added_far_past_the_right_edge_of_the_top_row() {
    let mut canvas = Canvas::new(2, 2);
    canvas.add((5, 0), RED);
    assert_eq!(canvas, Canvas::new(2, 2));
}

#[test]
fn should_not_wrap_a_cover_just_past_the_right_edge_onto_the_next_row() {
    let mut canvas = Canvas::new(2, 2);
    canvas.cover((2, 0), RED, 1.0);
    assert_eq!(rgb(canvas.get(0, 1)), [0, 0, 0]);
}
