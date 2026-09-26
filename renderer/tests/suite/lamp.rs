//! AT-7.7: the lamp over a quiet scene shows the latest outcome.

use fun_ci_renderer::animator::{Outcome, lamp};
use fun_ci_renderer::art::canvas::Canvas;
use fun_ci_renderer::art::Shade;

/// The lamp's centre on a 112-pixel header: `LAMP_AT`, 10 in and 12 up.
const LAMP_PIXEL: (usize, usize) = (10, 100);

/// The pixel at the lamp's centre, on a black header, `t` seconds in.
fn lamp_light(outcome: Outcome, t: f64) -> Shade {
    let mut canvas = Canvas::new(320, 112);
    lamp(&mut canvas, outcome, t);
    canvas.get(LAMP_PIXEL.0, LAMP_PIXEL.1)
}

/// The lamp's reddest moment over its first four seconds, in tenths of a second.
fn reddest(outcome: Outcome) -> Shade {
    let moments = (0..40).map(|tenth| lamp_light(outcome, f64::from(tenth) / 10.0));
    moments.max_by(|a, b| a[0].total_cmp(&b[0])).unwrap()
}

#[test]
fn should_glow_green_after_a_pass() {
    let [red, green, blue] = lamp_light(Outcome::Passed, 1.0);
    assert!(green > red * 2.0 && green > blue * 2.0 && green > 0.2, "{:?}", [red, green, blue]);
}

#[test]
fn should_glow_red_after_a_failure_when_its_flicker_is_bright() {
    let [red, green, blue] = reddest(Outcome::Failed);
    assert!(red > green * 2.0 && red > blue * 2.0 && red > 0.2, "{:?}", [red, green, blue]);
}

/// How far the lamp's brightest channel swings over its first four seconds.
fn swing(outcome: Outcome) -> f64 {
    let peaks: Vec<f64> = (0..40).map(|tenth| lamp_light(outcome, f64::from(tenth) / 10.0).into_iter().fold(0.0, f64::max)).collect();
    peaks.iter().copied().fold(0.0, f64::max) - peaks.iter().copied().fold(f64::MAX, f64::min)
}

#[test]
fn should_flicker_after_a_failure() {
    assert!(swing(Outcome::Failed) > 0.3, "{}", swing(Outcome::Failed));
}

#[test]
fn should_hold_steady_after_a_pass() {
    assert!(swing(Outcome::Passed) < 0.01, "{}", swing(Outcome::Passed));
}
