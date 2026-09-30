//! The one firefly an all-green board gets (design.md, The console): only
//! when everything has passed and nothing runs, dim, right of the middle,
//! wandering between two lines in the open space below the table.

use fun_ci_renderer::model::Board;
use fun_ci_renderer::table::firefly::{line, mote, still};
use fun_ci_renderer::table::night;
use serde_json::json;

fn board(statuses: &[&str]) -> Board {
    let runs: Vec<_> = statuses.iter().enumerate().map(|(i, status)| json!({"id": i, "sha": "0", "branch": format!("b{i}"), "status": status, "updated_at": 0, "stages": []})).collect();
    serde_json::from_value(json!({"now": 0, "runs": runs})).unwrap()
}

/// The moments of a minute, a tenth of a second apart.
fn a_minute() -> impl Iterator<Item = u64> {
    (0..600).map(|tenth| tenth * 100)
}

#[test]
fn a_board_of_passed_and_cancelled_runs_is_still() {
    assert!(still(&board(&["passed", "cancelled"])));
}

#[test]
fn a_board_with_a_run_running_is_not_still() {
    assert!(!still(&board(&["passed", "running"])));
}

#[test]
fn a_board_with_a_run_waiting_to_start_is_not_still() {
    assert!(!still(&board(&["passed", "pending"])));
}

#[test]
fn an_empty_board_is_not_still() {
    assert!(!still(&board(&[])));
}

#[test]
fn the_firefly_never_glows_brighter_than_its_peak() {
    assert!(a_minute().all(|ms| mote(120, ms).colour.iter().zip(night::FIREFLY).all(|(c, peak)| c <= &peak)));
}

#[test]
fn the_firefly_glows_and_fades() {
    let glows: Vec<[u8; 3]> = a_minute().map(|ms| mote(120, ms).colour).collect();

    assert!(glows.iter().any(|colour| *colour != glows[0]));
}

#[test]
fn the_firefly_stays_right_of_the_middle() {
    assert!(a_minute().all(|ms| (60..=90).contains(&mote(120, ms).column)));
}

#[test]
fn the_firefly_wanders_along_its_line() {
    assert!(a_minute().any(|ms| mote(120, ms).column != mote(120, 0).column));
}

#[test]
fn the_firefly_keeps_to_the_middle_of_the_open_lines() {
    assert!(a_minute().all(|ms| line(&[20, 21, 22, 23, 24, 25], ms).is_some_and(|at| (22..=23).contains(&at))));
}

#[test]
fn without_open_lines_there_is_no_firefly() {
    assert_eq!(line(&[], 0), None);
}

#[test]
fn the_firefly_at_its_brightest_is_no_brighter_than_a_passed_branch_s_name() {
    let sum = |colour: [u8; 3]| colour.iter().map(|c| u32::from(*c)).sum::<u32>();

    assert!(sum(night::FIREFLY) <= sum(night::pale(night::BRANCH)));
}
