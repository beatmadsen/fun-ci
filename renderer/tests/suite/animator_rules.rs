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
    a_pinned_success_animation_is_played: pinned("yay").success().name().to_string() => "yay";
    pinning_a_failure_leaves_the_success_choice_random: pinned("explosion").success().name().to_string() => "success";
    an_unknown_pin_is_ignored: pinned("disco").success().name().to_string() => "success";
    strip_removes_sgr_escapes: strip("\u{1b}[1;31mBOOM\u{1b}[0m!") => "BOOM!";
    strip_removes_other_csi_escapes: strip("a\u{1b}[2Kb") => "ab";
    strip_keeps_an_escape_that_is_not_csi: strip("a\u{1b}Xb") => "a\u{1b}Xb";
}

#[test]
fn an_unpinned_success_animation_is_chosen_by_the_seed() {
    let mut cast = Cast::new(Library::builtin(), 1);
    assert_eq!(cast.success().name(), "celebrate");
}

#[test]
fn unpinned_success_animations_follow_the_xorshift_sequence_of_the_seed() {
    let mut cast = Cast::new(Library::builtin(), 1);
    let picks = [(); 5].map(|()| cast.success().name().to_string());
    assert_eq!(picks, ["celebrate", "success", "flash", "success", "leprechauns"]);
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
