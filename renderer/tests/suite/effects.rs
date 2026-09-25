//! Stage effects and footer banners in situations the golden scenarios do not
//! reach: several runs, several effects at once, projects, late stages.

use crate::support::boards::{board, bold_at_word, event, last_screen, run, then_ticks};

const FIRST_ROW: usize = 14;
const SECOND_ROW: usize = 16;

fn passed(stages: &[&'static str]) -> Vec<(&'static str, &'static str)> {
    stages.iter().map(|s| (*s, "passed")).collect()
}

#[test]
fn an_effect_on_the_second_run_flashes_the_second_row() {
    let lines = [board(&[run(1, "passed", &passed(&["lint"])), run(2, "running", &passed(&["lint"]))]),
                 event("stage_passed", 2, "lint")];
    assert!(bold_at_word(&last_screen(&then_ticks(&lines, 1)), SECOND_ROW, "Lint"));
}

#[test]
fn a_failure_banner_outranks_a_success_banner() {
    let lines = [board(&[run(1, "failed", &[("fast", "failed")]), run(2, "passed", &passed(&["fast"]))]),
                 event("stage_passed", 2, "fast"), event("stage_failed", 1, "fast")];
    assert!(last_screen(&then_ticks(&lines, 9)).text().contains(">>> FAST FAILED <<<"));
}

#[test]
fn of_two_failure_banners_the_first_shows() {
    let lines = [board(&[run(1, "failed", &[("lint", "failed")]), run(2, "failed", &[("build", "failed")])]),
                 event("stage_failed", 1, "lint"), event("stage_failed", 2, "build")];
    assert!(last_screen(&then_ticks(&lines, 9)).text().contains(">>> LINT FAILED <<<"));
}

#[test]
fn a_timeout_flash_does_not_hide_a_success_banner() {
    let success = [board(&[run(1, "passed", &passed(&["fast"])), run(2, "timeout", &[("fast", "timeout")])]),
                   event("stage_passed", 1, "fast")];
    let lines = [then_ticks(&success, 8), vec![event("stage_failed", 2, "fast")]].concat();
    assert!(last_screen(&then_ticks(&lines, 1)).text().contains("NICE!"));
}

#[test]
fn a_timeout_flash_ends_after_four_frames() {
    let lines = [board(&[run(1, "timeout", &[("fast", "timeout")])]), event("stage_failed", 1, "fast")];
    assert!(bold_at_word(&last_screen(&then_ticks(&lines, 6)), FIRST_ROW, "Fast"));
}

#[test]
fn a_repeated_failure_starts_its_banner_again() {
    let failed = [board(&[run(1, "failed", &[("lint", "failed")])]), event("stage_failed", 1, "lint")];
    let lines = [then_ticks(&failed, 9), vec![event("stage_failed", 1, "lint")]].concat();
    assert!(!last_screen(&then_ticks(&lines, 1)).text().contains("FAILED <<<"));
}

#[test]
fn an_effect_lands_exactly_on_its_stage_when_the_run_names_a_project() {
    let mut project_run = run(1, "running", &passed(&["lint"]));
    project_run["project"] = "/src/app".into();
    let lines = [board(&[project_run]), event("stage_passed", 1, "lint")];
    let text = last_screen(&then_ticks(&lines, 1)).text();
    assert_eq!(text.lines().nth(FIRST_ROW).unwrap().trim_end(), "  a3f7c01  b1  app  Lint 0.3s  RUNNING  just now");
}

#[test]
fn the_build_sparkle_starts_two_frames_late() {
    let lines = [board(&[run(1, "passed", &passed(&["lint", "build"]))]), event("stage_passed", 1, "build")];
    assert!(!bold_at_word(&last_screen(&then_ticks(&lines, 1)), FIRST_ROW, "Build"));
}

#[test]
fn the_slow_sparkle_starts_six_frames_late() {
    let lines = [board(&[run(1, "passed", &passed(&["lint", "slow"]))]), event("stage_passed", 1, "slow")];
    assert!(!bold_at_word(&last_screen(&then_ticks(&lines, 5)), FIRST_ROW, "Slow"));
}

#[test]
fn the_slow_sparkle_lights_its_first_letter_on_the_seventh_frame() {
    let lines = [board(&[run(1, "passed", &passed(&["lint", "slow"]))]), event("stage_passed", 1, "slow")];
    assert!(bold_at_word(&last_screen(&then_ticks(&lines, 7)), FIRST_ROW, "Slow"));
}
