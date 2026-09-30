//! Stage effects and footer banners in situations the golden scenarios do not
//! reach: several runs, several effects at once, projects, late stages.

use crate::support::boards::{board, event, last_screen, mark, row_of, run, then_ticks};
use fun_ci_renderer::grid::Colour;
use fun_ci_renderer::table::night;

/// The first run's row after `lines` and `ticks` ticks, as text: the same with
/// and without an effect when the effect lands exactly on its stage's mark.
fn row_after(lines: &[String], ticks: usize) -> String {
    let screen = last_screen(&then_ticks(lines, ticks));
    screen.text().lines().nth(row_of(&screen, "b1")).unwrap().to_string()
}

/// Whether `branch`'s `stage` mark is bold after `lines` and `ticks` ticks.
fn bold_after(lines: &[String], ticks: usize, (branch, stage): (&str, &str)) -> bool {
    mark(&last_screen(&then_ticks(lines, ticks)), branch, stage).attrs.contains(&"bold")
}

/// The colour of `branch`'s `stage` mark after `lines` and `ticks` ticks.
fn colour_after(lines: &[String], ticks: usize, (branch, stage): (&str, &str)) -> Colour {
    mark(&last_screen(&then_ticks(lines, ticks)), branch, stage).fg
}

fn rgb([r, g, b]: [u8; 3]) -> Colour {
    Colour::Rgb(r, g, b)
}

fn passed(stages: &[&'static str]) -> Vec<(&'static str, &'static str)> {
    stages.iter().map(|s| (*s, "passed")).collect()
}

#[test]
fn an_effect_on_the_second_run_flashes_the_second_row() {
    let lines = [board(&[run(1, "passed", &passed(&["lint"])), run(2, "running", &passed(&["lint"]))]),
                 event("stage_passed", 2, "lint")];
    assert!(bold_after(&lines, 1, ("b2", "lint")));
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
    assert_eq!(colour_after(&lines, 6, ("b1", "fast")), rgb(night::TIMED_OUT));
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
    assert_eq!(row_after(&lines, 1), row_after(&lines[..1], 1));
}

#[test]
fn the_build_sparkle_starts_two_frames_late() {
    let lines = [board(&[run(1, "passed", &passed(&["lint", "build"]))]), event("stage_passed", 1, "build")];
    assert_eq!(colour_after(&lines, 1, ("b1", "build")), rgb([42, 69, 64]));
}

#[test]
fn the_slow_sparkle_starts_six_frames_late() {
    let lines = [board(&[run(1, "passed", &passed(&["lint", "slow"]))]), event("stage_passed", 1, "slow")];
    assert_eq!(colour_after(&lines, 5, ("b1", "slow")), rgb([42, 69, 64]));
}

#[test]
fn the_slow_sparkle_lights_its_first_letter_on_the_seventh_frame() {
    let lines = [board(&[run(1, "passed", &passed(&["lint", "slow"]))]), event("stage_passed", 1, "slow")];
    assert!(bold_after(&lines, 7, ("b1", "slow")));
}

#[test]
fn an_effect_lands_exactly_on_its_stage_when_the_run_conflicts_with_the_trunk() {
    let mut conflicting = run(1, "running", &passed(&["lint"]));
    conflicting["trunk"] = serde_json::json!({"branch_state": "conflicts", "trunk": "main"});
    let lines = [board(&[conflicting]), event("stage_passed", 1, "lint")];
    assert_eq!(row_after(&lines, 1), row_after(&lines[..1], 1));
}

#[test]
fn an_effect_on_the_row_in_the_block_keeps_the_block_under_it() {
    let mut running: serde_json::Value = serde_json::from_str(&board(&[run(1, "running", &[("lint", "passed"), ("build", "passed")])])).unwrap();
    running["cursor"] = serde_json::json!(0);
    let lines = [running.to_string(), event("stage_passed", 1, "build")];
    let screen = last_screen(&then_ticks(&lines, 1));

    assert_eq!(mark(&screen, "b1", "build").bg, rgb(night::WINE));
}

#[test]
fn a_timeout_flashes_its_mark_at_once() {
    let lines = [board(&[run(1, "timeout", &[("fast", "timeout")])]), event("stage_failed", 1, "fast")];
    assert!(bold_after(&lines, 1, ("b1", "fast")));
}

#[test]
fn the_build_sparkle_lights_its_mark_on_the_third_frame() {
    let lines = [board(&[run(1, "passed", &passed(&["lint", "build"]))]), event("stage_passed", 1, "build")];
    assert!(bold_after(&lines, 3, ("b1", "build")));
}

#[test]
fn a_banner_is_not_drawn_over_a_board_emptied_while_it_plays() {
    let lines = [board(&[run(1, "failed", &[("fast", "failed")])]), event("stage_failed", 1, "fast")];
    let emptied = [then_ticks(&lines, 9), then_ticks(&[board(&[])], 2)].concat();

    assert!(!last_screen(&emptied).text().contains("FAILED <<<"));
}
