//! Which effect an event calls for, which animation is chosen, and how
//! escapes are measured.

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::animator::{Animator, Cast, Kind};
use fun_ci_renderer::model::Event;
use fun_ci_renderer::ansi::strip;

macro_rules! cases {
    ($($name:ident: $actual:expr => $expected:expr;)*) => {
        $(#[test] fn $name() { assert_eq!($actual, $expected); })*
    };
}

fn pinned(name: &str) -> Cast {
    let mut cast = Cast::new(Library::builtin(), 0);
    cast.pin(name);
    cast
}

cases! {
    a_failed_stage_explodes: Kind::for_event("stage_failed", "failed", "failed") => Some(Kind::Failure);
    a_timed_out_stage_flashes_yellow: Kind::for_event("stage_failed", "timeout", "timeout") => Some(Kind::Timeout);
    the_stage_that_finishes_a_run_celebrates: Kind::for_event("stage_passed", "passed", "passed") => Some(Kind::Success);
    a_stage_that_passes_mid_run_flashes_green: Kind::for_event("stage_passed", "passed", "running") => Some(Kind::StagePass);
    a_run_event_has_no_stage_effect: Kind::for_event("run_passed", "passed", "passed") => None;
    pinning_a_scene_leaves_the_other_pools_to_pick_from: Cast::pool("run_passed").contains(&picked(&mut pinned("explosion"), "run_passed").as_str()) => true;
    an_unknown_pin_is_ignored: Cast::pool("run_passed").contains(&picked(&mut pinned("disco"), "run_passed").as_str()) => true;
    strip_removes_sgr_escapes: strip("\u{1b}[1;31mBOOM\u{1b}[0m!") => "BOOM!";
    strip_removes_other_csi_escapes: strip("a\u{1b}[2Kb") => "ab";
    strip_keeps_an_escape_that_is_not_csi: strip("a\u{1b}Xb") => "a\u{1b}Xb";
}

fn picked(cast: &mut Cast, milestone: &str) -> String {
    cast.for_milestone(milestone).unwrap().name().to_string()
}

fn picks(seed: u64, count: usize) -> Vec<String> {
    let mut cast = Cast::new(Library::builtin(), seed);
    (0..count).map(|_| picked(&mut cast, "run_passed")).collect()
}

#[test]
fn the_same_seed_picks_the_same_scenes() {
    assert_eq!(picks(5, 10), picks(5, 10));
}

#[test]
fn enough_picks_reach_every_scene_of_a_pool() {
    let mut seen = picks(5, 30);
    seen.sort();
    seen.dedup();
    assert_eq!(seen, ["celebrate", "leprechauns", "success"]);
}

#[test]
fn an_event_waiting_to_be_played_counts_as_animating() {
    let mut animator = Animator::new(Cast::new(Library::builtin(), 1));
    animator.queue(Event { name: "stage_failed".into(), run_id: Some(1), stage: Some("fast".into()), animation: None });
    assert!(animator.animating());
}

#[test]
fn nothing_queued_or_playing_is_not_animating() {
    assert!(!Animator::new(Cast::new(Library::builtin(), 1)).animating());
}
