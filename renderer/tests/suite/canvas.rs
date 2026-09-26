//! Painting on a canvas.

use fun_ci_renderer::art::canvas::Canvas;

use crate::support::shades::rgb;

const RED: [f64; 3] = [1.0, 0.0, 0.0];

#[test]
fn should_start_black() {
    assert_eq!(rgb(Canvas::new(2, 2).get(1, 1)), [0, 0, 0]);
}

#[test]
fn should_paint_the_last_pixel_of_a_rectangle() {
    let mut canvas = Canvas::new(4, 4);
    canvas.fill_rect((1, 1), (2, 2), RED);
    assert_eq!(rgb(canvas.get(2, 2)), [255, 0, 0]);
}

#[test]
fn should_leave_the_pixel_past_a_rectangle_alone() {
    let mut canvas = Canvas::new(4, 4);
    canvas.fill_rect((1, 1), (2, 2), RED);
    assert_eq!(rgb(canvas.get(3, 2)), [0, 0, 0]);
}

#[test]
fn should_clip_a_rectangle_when_it_runs_off_the_canvas() {
    let mut canvas = Canvas::new(2, 2);
    canvas.fill_rect((1, 1), (5, 5), RED);
    assert_eq!(rgb(canvas.get(1, 1)), [255, 0, 0]);
}
