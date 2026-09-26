//! The built-in scenes: which there are, how long each plays, how often the
//! idle one needs drawing, and what each draws at fixed moments, held as a
//! gallery of cell digests (the pictures themselves are reviewed as PNGs).

use fun_ci_renderer::animation::{Library, Scene};
use fun_ci_renderer::art::canvas::Canvas;
use fun_ci_renderer::art::cells::encode;

macro_rules! cases {
    ($($name:ident: $actual:expr => $expected:expr;)*) => {
        $(#[test] fn $name() { assert_eq!($actual, $expected); })*
    };
}

/// Moments to paint each scene at: through the event scenes' lengths, then
/// in the rocket pilot's blink (3.85-4 s) and during the idle sky's second
/// falling star (9-9.9 s).
const MOMENTS_MS: [u64; 9] = [0, 150, 400, 900, 1700, 2600, 3500, 3900, 9300];

fn scene(name: &str) -> &'static dyn Scene {
    Library::builtin().get(name).unwrap()
}

fn digest(scene: &dyn Scene, (cols, t_ms): (usize, u64)) -> String {
    let mut canvas = Canvas::new(cols * 4, 112);
    scene.paint(&mut canvas, t_ms);
    canvas.tone();
    format!("{cols:>3} cols at {t_ms:>4} ms: {:08x}", crc32fast::hash(format!("{:?}", encode(&canvas)).as_bytes()))
}

/// Digests of `name` at each moment on a 60-column header, then once on a 200-column one.
fn gallery(name: &str) -> String {
    let narrow = MOMENTS_MS.iter().map(|t| digest(scene(name), (60, *t)));
    narrow.chain([digest(scene(name), (200, 900))]).collect::<Vec<_>>().join("\n")
}

#[test]
fn should_hold_every_scene_the_events_and_scenarios_name() {
    assert_eq!(Library::builtin().names(), ["celebrate", "explosion", "flash", "idle", "leprechauns", "running", "success", "yay"]);
}

cases! {
    should_loop_the_idle_scene: scene("idle").length_ms() => None;
    should_loop_the_running_scene: scene("running").length_ms() => None;
    should_play_the_explosion_for_three_point_two_seconds: scene("explosion").length_ms() => Some(3200);
    should_play_the_fireworks_for_four_point_two_seconds: scene("success").length_ms() => Some(4200);
    should_play_the_trophy_for_four_seconds: scene("celebrate").length_ms() => Some(4000);
    should_play_the_storm_for_three_point_six_seconds: scene("flash").length_ms() => Some(3600);
    should_play_the_leprechauns_for_four_point_four_seconds: scene("leprechauns").length_ms() => Some(4400);
    should_play_yay_for_three_point_eight_seconds: scene("yay").length_ms() => Some(3800);
    should_draw_the_idle_scene_four_times_a_second: scene("idle").frame_ms() => 250;
    should_draw_a_scene_that_says_nothing_once_a_second: scene("explosion").frame_ms() => 1000;
}

macro_rules! galleries {
    ($($test:ident: $name:literal;)*) => {
        $(#[test] fn $test() { insta::assert_snapshot!(concat!("gallery-", $name), gallery($name)); })*
    };
}

galleries! {
    should_paint_the_night_sky_as_reviewed: "idle";
    should_paint_the_rocket_as_reviewed: "running";
    should_paint_the_explosion_as_reviewed: "explosion";
    should_paint_the_fireworks_as_reviewed: "success";
    should_paint_the_trophy_as_reviewed: "celebrate";
    should_paint_the_storm_as_reviewed: "flash";
    should_paint_the_leprechauns_as_reviewed: "leprechauns";
    should_paint_yay_as_reviewed: "yay";
}
