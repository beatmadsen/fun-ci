//! Stage effects and footer banners in situations the golden scenarios do not
//! reach: several runs, several effects at once, projects, late stages. A
//! mark's effect lights it in its own colour and fades back to how its row
//! draws it; the frames here are 100 ms apart, the first at the event.

use crate::support::boards::{board, event, last_screen, mark, row_of, run, then_ticks};
use fun_ci_renderer::animator::looks::{AMBER, FLARE, GOLD, WHITE};
use fun_ci_renderer::grid::Colour;
use fun_ci_renderer::table::night;

/// The first run's row after `lines` and `ticks` ticks, as text: the same with
/// and without an effect when the effect lands exactly on its stage's mark.
fn row_after(lines: &[String], ticks: usize) -> String {
    let screen = last_screen(&then_ticks(lines, ticks));
    screen.text().lines().nth(row_of(&screen, "b1")).unwrap().to_string()
}

/// The background of `branch`'s `stage` mark after `lines` and `ticks` ticks.
fn paper_after(lines: &[String], ticks: usize, (branch, stage): (&str, &str)) -> Colour {
    mark(&last_screen(&then_ticks(lines, ticks)), branch, stage).bg
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
fn an_effect_on_the_second_run_lights_the_second_row() {
    let lines = [board(&[run(1, "passed", &passed(&["lint"])), run(2, "running", &passed(&["lint"]))]),
                 event("stage_passed", 2, "lint")];
    assert_eq!(colour_after(&lines, 1, ("b2", "lint")), rgb(GOLD));
}

#[test]
fn a_stage_passing_mid_run_is_back_to_its_own_colour_after_three_tenths_of_a_second() {
    let lines = [board(&[run(1, "running", &passed(&["lint"]))]), event("stage_passed", 1, "lint")];
    assert_eq!(colour_after(&lines, 4, ("b1", "lint")), colour_after(&lines[..1], 4, ("b1", "lint")));
}

#[test]
fn a_stage_passing_mid_run_fades_from_gold_rather_than_jumping_back() {
    let lines = [board(&[run(1, "running", &passed(&["lint"]))]), event("stage_passed", 1, "lint")];
    let halfway = colour_after(&lines, 2, ("b1", "lint"));
    assert!(halfway != rgb(GOLD) && halfway != colour_after(&lines[..1], 2, ("b1", "lint")), "{halfway:?}");
}

#[test]
fn a_failed_stage_flares_white_on_red_at_once() {
    let lines = [board(&[run(1, "failed", &[("fast", "failed")])]), event("stage_failed", 1, "fast")];
    assert_eq!((colour_after(&lines, 1, ("b1", "fast")), paper_after(&lines, 1, ("b1", "fast"))), (rgb(WHITE), rgb(FLARE)));
}

#[test]
fn a_failed_stage_cools_to_how_its_row_draws_it_within_a_second() {
    let lines = [board(&[run(1, "failed", &[("fast", "failed")])]), event("stage_failed", 1, "fast")];
    let cooled = (colour_after(&lines, 11, ("b1", "fast")), paper_after(&lines, 11, ("b1", "fast")));
    assert_eq!(cooled, (colour_after(&lines[..1], 11, ("b1", "fast")), paper_after(&lines[..1], 11, ("b1", "fast"))));
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
fn a_timeout_is_back_to_its_own_colour_after_four_tenths_of_a_second() {
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
fn the_build_mark_waits_its_turn() {
    let lines = [board(&[run(1, "passed", &passed(&["lint", "build"]))]), event("stage_passed", 1, "build")];
    assert_eq!(colour_after(&lines, 1, ("b1", "build")), rgb([42, 69, 64]));
}

#[test]
fn the_slow_mark_waits_its_turn() {
    let lines = [board(&[run(1, "passed", &passed(&["lint", "slow"]))]), event("stage_passed", 1, "slow")];
    assert_eq!(colour_after(&lines, 5, ("b1", "slow")), rgb([42, 69, 64]));
}

#[test]
fn the_slow_mark_lights_gold_on_its_turn_six_tenths_of_a_second_in() {
    let lines = [board(&[run(1, "passed", &passed(&["lint", "slow"]))]), event("stage_passed", 1, "slow")];
    assert_eq!(colour_after(&lines, 7, ("b1", "slow")), rgb(GOLD));
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

    assert_eq!(mark(&screen, "b1", "build").bg, rgb(night::INDIGO));
}

#[test]
fn a_timeout_lights_its_mark_amber_at_once() {
    let lines = [board(&[run(1, "timeout", &[("fast", "timeout")])]), event("stage_failed", 1, "fast")];
    assert_eq!(colour_after(&lines, 1, ("b1", "fast")), rgb(AMBER));
}

#[test]
fn a_timeout_lights_its_mark_amber_again_two_tenths_of_a_second_in() {
    let lines = [board(&[run(1, "timeout", &[("fast", "timeout")])]), event("stage_failed", 1, "fast")];
    assert_eq!(colour_after(&lines, 3, ("b1", "fast")), rgb(AMBER));
}

#[test]
fn the_build_mark_lights_gold_on_its_turn_two_tenths_of_a_second_in() {
    let lines = [board(&[run(1, "passed", &passed(&["lint", "build"]))]), event("stage_passed", 1, "build")];
    assert_eq!(colour_after(&lines, 3, ("b1", "build")), rgb(GOLD));
}

#[test]
fn a_banner_is_not_drawn_over_a_board_emptied_while_it_plays() {
    let lines = [board(&[run(1, "failed", &[("fast", "failed")])]), event("stage_failed", 1, "fast")];
    let emptied = [then_ticks(&lines, 9), then_ticks(&[board(&[])], 2)].concat();

    assert!(!last_screen(&emptied).text().contains("FAILED <<<"));
}

#[test]
fn a_mark_waiting_its_turn_still_lights_when_another_run_s_stage_passes_meanwhile() {
    let finished = [board(&[run(1, "passed", &passed(&["lint", "slow"])), run(2, "running", &passed(&["lint"]))]),
                    event("stage_passed", 1, "slow")];
    let lines = [then_ticks(&finished, 1), vec![event("stage_passed", 2, "lint")]].concat();
    assert_eq!(colour_after(&lines, 6, ("b1", "slow")), rgb(GOLD));
}

#[test]
fn a_new_effect_on_a_mark_drops_what_the_one_before_it_had_still_to_play() {
    let timed_out = [board(&[run(1, "timeout", &[("fast", "timeout")])]), event("stage_failed", 1, "fast")];
    let failed = [board(&[run(1, "failed", &[("fast", "failed")])]), event("stage_failed", 1, "fast")];
    let lines = [then_ticks(&timed_out, 1), failed.to_vec()].concat();
    assert_ne!(colour_after(&lines, 2, ("b1", "fast")), rgb(AMBER));
}

/// Run 1's fast suite failing, flared; then `then`, a frame each; then a board
/// with run 3 above run 1, so every row after the first moves down one.
fn rows_moving_under(then: &[String]) -> Vec<String> {
    let failing = [run(1, "failed", &[("fast", "failed")]), run(2, "failed", &[("fast", "failed")])];
    let moved = board(&[run(3, "passed", &passed(&["fast"])), failing[0].clone(), failing[1].clone()]);
    let start = [board(&failing), event("stage_failed", 1, "fast")];
    [then_ticks(&start, 1), then.iter().flat_map(|line| then_ticks(std::slice::from_ref(line), 1)).collect(), vec![moved]].concat()
}

/// The same lines with no events: how each mark looks at rest.
fn at_rest(lines: &[String]) -> Vec<String> {
    lines.iter().filter(|line| !line.contains("\"event\"")).cloned().collect()
}

#[test]
fn an_effect_follows_its_mark_when_the_rows_move() {
    let lines = rows_moving_under(&[event("stage_failed", 2, "fast")]);
    assert_ne!(paper_after(&lines, 1, ("b1", "fast")), paper_after(&at_rest(&lines), 1, ("b1", "fast")));
}

#[test]
fn an_effect_replaced_on_its_mark_leaves_nothing_where_the_mark_was_when_the_rows_move() {
    let lines = rows_moving_under(&[event("stage_failed", 1, "fast")]);
    assert_eq!(paper_after(&lines, 1, ("b3", "fast")), paper_after(&at_rest(&lines), 1, ("b3", "fast")));
}
