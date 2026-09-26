//! The tools scenes paint with: glows, streaks, squares, sprites,
//! noise and the tone curve.

use fun_ci_renderer::art::canvas::Canvas;
use fun_ci_renderer::art::light::{glow, square, streak};
use fun_ci_renderer::art::noise::{dice, fbm, value};
use fun_ci_renderer::art::sprite::Sprite;

use crate::support::shades::rgb;

const RED: [f64; 3] = [1.0, 0.0, 0.0];
const HALF_RED: [f64; 3] = [0.5, 0.0, 0.0];

fn canvas() -> Canvas {
    Canvas::new(9, 9)
}

fn glowing(radius: f64) -> Canvas {
    let mut canvas = canvas();
    glow(&mut canvas, (4.5, 4.5), radius, HALF_RED);
    canvas
}

fn toned(pixel: [f64; 3]) -> [u8; 3] {
    let mut canvas = Canvas::new(1, 1);
    canvas.add((0, 0), pixel);
    canvas.tone();
    rgb(canvas.get(0, 0))
}

#[test]
fn should_add_all_of_a_glows_light_at_its_centre() {
    assert_eq!(rgb(glowing(2.0).get(4, 4)), [128, 0, 0]);
}

#[test]
fn should_add_a_glows_light_divided_by_e_one_radius_out() {
    assert_eq!(rgb(glowing(2.0).get(6, 4)), [47, 0, 0]);
}

#[test]
fn should_add_a_glows_light_divided_by_e_to_the_fourth_two_radii_out() {
    assert_eq!(rgb(glowing(2.0).get(8, 4)), [2, 0, 0]);
}

#[test]
fn should_add_no_light_beyond_three_radii_of_a_glow_when_it_is_blinding() {
    let mut canvas = canvas();
    glow(&mut canvas, (4.5, 4.5), 1.0, [1.0e6, 0.0, 0.0]);
    assert_eq!(rgb(canvas.get(8, 4)), [0, 0, 0]);
}

#[test]
fn should_light_the_middle_of_a_streak_fully() {
    let mut canvas = canvas();
    streak(&mut canvas, ((1.5, 4.5), (7.5, 4.5)), 1.0, RED);
    assert_eq!(rgb(canvas.get(4, 4)), [255, 0, 0]);
}

#[test]
fn should_cover_a_pixel_by_the_share_of_it_a_square_overlaps() {
    let mut canvas = canvas();
    square(&mut canvas, (0.5, 0.0), (1.0, 1.0), RED);
    assert_eq!(rgb(canvas.get(0, 0)), [128, 0, 0]);
}

#[test]
fn should_stamp_a_sprite_pixel_in_its_palette_colour() {
    let mut canvas = canvas();
    Sprite { rows: &[".r"], palette: &[('r', RED)] }.stamp(&mut canvas, (0.0, 0.0), 2.0);
    assert_eq!(rgb(canvas.get(3, 1)), [255, 0, 0]);
}

#[test]
fn should_leave_clear_a_sprite_pixel_the_palette_has_no_colour_for() {
    let mut canvas = canvas();
    Sprite { rows: &[".r"], palette: &[('r', RED)] }.stamp(&mut canvas, (0.0, 0.0), 2.0);
    assert_eq!(rgb(canvas.get(1, 1)), [0, 0, 0]);
}

#[test]
fn should_give_the_same_number_when_the_dice_are_thrown_again_for_the_same_index() {
    assert_eq!(dice(3, 7).to_bits(), dice(3, 7).to_bits());
}

#[test]
fn should_give_another_number_when_the_salt_differs() {
    assert_ne!(dice(3, 7).to_bits(), dice(3, 8).to_bits());
}

#[test]
fn should_change_value_noise_only_a_little_when_the_point_moves_a_little() {
    assert!((value(2.4995, 5.7, 1) - value(2.5005, 5.7, 1)).abs() < 0.01);
}

#[test]
fn should_change_fractal_noise_only_a_little_when_the_point_moves_a_little() {
    assert!((fbm(2.4995, 5.7, 1) - fbm(2.5005, 5.7, 1)).abs() < 0.02);
}

#[test]
fn should_leave_light_below_the_knee_as_it_is_when_toned() {
    assert_eq!(toned([0.5, 0.0, 0.0]), [128, 0, 0]);
}

#[test]
fn should_bend_light_above_the_knee_towards_white_when_toned() {
    assert_eq!(toned([0.9, 0.0, 0.0]), [220, 0, 0]);
}

#[test]
fn should_spill_light_over_white_into_the_other_channels_when_toned() {
    assert_eq!(toned([2.0, 0.0, 0.0])[1], 89);
}
