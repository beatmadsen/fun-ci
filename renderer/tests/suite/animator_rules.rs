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
    assert_eq!(seen, ["celebrate", "leprechauns", "success", "sunrise"]);
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

/// How long a quiet scene shows before the next one takes over.
const FIVE_MINUTES: u64 = 300_000;

#[test]
fn the_quiet_scene_picked_holds_for_five_minutes() {
    let mut cast = Cast::new(Library::builtin(), 5);
    let mut names: Vec<&str> = (0..20).map(|i| cast.quiet(i * (FIVE_MINUTES - 1) / 19).name()).collect();
    names.dedup();
    assert_eq!(names.len(), 1, "{names:?}");
}

#[test]
fn another_quiet_scene_takes_over_after_five_minutes() {
    let mut cast = Cast::new(Library::builtin(), 5);
    let first = cast.quiet(0).name();
    assert_ne!(cast.quiet(FIVE_MINUTES).name(), first);
}

#[test]
fn the_quiet_scene_that_took_over_holds_for_five_minutes_of_its_own() {
    let mut cast = Cast::new(Library::builtin(), 5);
    cast.quiet(0);
    let second = cast.quiet(FIVE_MINUTES).name();
    assert_eq!(cast.quiet(2 * FIVE_MINUTES - 1).name(), second);
}

#[test]
fn quiet_scenes_keep_taking_over_every_five_minutes() {
    let mut cast = Cast::new(Library::builtin(), 5);
    let mut names: Vec<&str> = (0..12).map(|i| cast.quiet(i * FIVE_MINUTES).name()).collect();
    names.dedup();
    assert_eq!(names.len(), 12, "{names:?}");
}

/// The scene one quiet spell shows, ending the spell.
fn quiet_spell(cast: &mut Cast) -> &'static str {
    let name = cast.quiet(0).name();
    cast.wake();
    name
}

#[test]
fn each_quiet_spell_picks_its_scene_afresh() {
    let mut cast = Cast::new(Library::builtin(), 5);
    let mut names: Vec<&str> = (0..10).map(|_| quiet_spell(&mut cast)).collect();
    names.sort_unstable();
    names.dedup();
    assert!(names.len() > 1, "{names:?}");
}

#[test]
fn a_pinned_quiet_scene_is_the_one_the_quiet_spell_shows() {
    let mut cast = pinned("fireflies");
    assert_eq!(cast.quiet(0).name(), "fireflies");
}

#[test]
fn a_pinned_quiet_scene_holds_past_five_minutes() {
    let mut cast = pinned("fireflies");
    cast.quiet(0);
    assert_eq!(cast.quiet(FIVE_MINUTES).name(), "fireflies");
}

#[test]
fn the_milestones_are_named_in_the_order_a_run_reaches_them() {
    assert_eq!(fun_ci_renderer::animator::MILESTONES, ["lint_passed", "build_passed", "fast_passed", "run_passed", "run_failed"]);
}

#[test]
fn a_pinned_scene_is_every_pick_its_pool_makes() {
    let mut cast = pinned("yay");
    let picks: Vec<String> = (0..20).map(|_| picked(&mut cast, "fast_passed")).collect();
    assert_eq!(picks, vec!["yay"; 20]);
}

#[test]
fn pinning_another_scene_of_the_same_pool_replaces_the_first_pin() {
    let mut cast = pinned("flash");
    cast.pin("yay");
    assert_eq!(picked(&mut cast, "fast_passed"), "yay");
}

#[test]
fn random_picks_spread_evenly_across_a_pool() {
    let picks = picks(5, 400);
    let counts = ["success", "celebrate", "leprechauns", "sunrise"].map(|name| picks.iter().filter(|pick| *pick == name).count());
    assert!(counts.iter().all(|count| *count >= 70), "{counts:?}");
}

#[test]
fn the_header_keeps_animating_while_a_queued_scene_plays() {
    let mut animator = Animator::new(Cast::new(Library::builtin(), 1));
    animator.queue(Event { name: "run_passed".into(), run_id: Some(1), stage: None, animation: Some("success".into()) });
    let mut screen = fun_ci_renderer::screen::Screen::new(80);
    animator.render(&mut screen, &fun_ci_renderer::model::Board::default(), fun_ci_renderer::model::Moment { board_ms: 0, play_ms: 0 });
    assert!(animator.animating(), "the fireworks are still playing");
}

/// The header scene an animator shows for a board holding `runs`, one frame on.
fn shown(animator: &mut Animator, runs: &[serde_json::Value], frame: u64) -> String {
    let board: fun_ci_renderer::model::Board = serde_json::from_value(serde_json::json!({ "runs": runs })).unwrap();
    let mut screen = fun_ci_renderer::screen::Screen::new(80);
    animator.render(&mut screen, &board, fun_ci_renderer::model::Moment { board_ms: 0, play_ms: frame * 100 })
}

/// The quiet scene shown once a run has run: a frame with it running, then one with nothing.
fn quiet_after_a_run(animator: &mut Animator, spell: u64) -> String {
    shown(animator, &[crate::support::boards::run(2, "running", &[])], spell * 2);
    shown(animator, &[], spell * 2 + 1)
}

#[test]
fn each_quiet_spell_after_a_run_picks_its_scene_afresh() {
    let mut animator = Animator::new(Cast::new(Library::builtin(), 5));
    let mut quiet: Vec<String> = (0..10).map(|spell| quiet_after_a_run(&mut animator, spell)).collect();
    quiet.sort();
    quiet.dedup();
    assert!(quiet.len() > 1, "{quiet:?}");
}

#[test]
fn the_header_holds_its_quiet_scene_from_frame_to_frame() {
    let mut animator = Animator::new(Cast::new(Library::builtin(), 5));
    let mut scenes: Vec<String> = (0..20).map(|frame| shown(&mut animator, &[], frame)).collect();
    scenes.dedup();
    assert_eq!(scenes.len(), 1, "{scenes:?}");
}
