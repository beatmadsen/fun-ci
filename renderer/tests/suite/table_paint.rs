//! Each row of the table as it is drawn: one phrase, name, marks, words and
//! age; pale once passed, quiet once cancelled; the lead's name bold. The
//! block behind the lead's row is the sheet's (`table_sheet.rs`).

use crate::support::paint::{COLUMNS, at, drawn, failed, fg, passed, rgb, run, text};
use fun_ci_renderer::grid::Colour;
use fun_ci_renderer::table::night;
use fun_ci_renderer::table::stack::Piece;

#[test]
fn a_row_names_its_branch_where_names_start() {
    assert!(at(&drawn(&Piece::Row(&failed()), None, &[]), COLUMNS.branch).starts_with("feat "));
}

#[test]
fn a_row_s_marks_start_at_the_strip_linked_into_a_track() {
    assert!(at(&drawn(&Piece::Row(&failed()), None, &[]), COLUMNS.strip).starts_with("✓─✓─◆┄·"));
}

#[test]
fn a_row_says_what_happened_after_its_marks() {
    assert!(at(&drawn(&Piece::Row(&failed()), None, &[]), COLUMNS.words).starts_with("failed in fast · 1.4s "));
}

#[test]
fn a_row_ends_with_its_age() {
    assert!(text(&drawn(&Piece::Row(&failed()), None, &[])).trim_end().ends_with(" 6m"));
}

#[test]
fn a_passed_row_is_pale() {
    assert_eq!(fg(&drawn(&Piece::Row(&passed()), None, &[]), COLUMNS.branch), rgb([82, 80, 88]));
}

#[test]
fn the_lead_s_name_is_bold_in_the_cursor_s_colour() {
    let grid = drawn(&Piece::Row(&passed()), Some(2), &[]);

    assert_eq!((fg(&grid, COLUMNS.branch), grid.cells[0][14].attrs.clone()), (rgb(night::CURSOR), vec!["bold"]));
}

#[test]
fn the_lead_s_row_is_not_pale() {
    assert_eq!(fg(&drawn(&Piece::Row(&passed()), Some(2), &[]), COLUMNS.strip), rgb(night::PASSED));
}

#[test]
fn a_cancelled_row_s_name_is_quiet() {
    let run = run(5, "detached", "cancelled", &[]);

    assert_eq!(fg(&drawn(&Piece::Row(&run), None, &[]), COLUMNS.branch), rgb(night::QUIET));
}

fn stripe(run: &fun_ci_renderer::model::Run) -> (String, Colour) {
    let grid = drawn(&Piece::Row(run), None, &[]);
    (grid.cells[0][COLUMNS.margin].text.clone(), fg(&grid, COLUMNS.margin))
}

#[test]
fn a_failed_row_has_a_stripe_in_the_failed_colour() {
    assert_eq!(stripe(&failed()), ("▌".to_string(), rgb(night::FAILED)));
}

#[test]
fn a_timed_out_row_has_a_stripe_in_the_timed_out_colour() {
    assert_eq!(stripe(&run(7, "slow", "timeout", &[])).1, rgb(night::TIMED_OUT));
}

#[test]
fn a_running_row_has_a_stripe_in_the_running_colour() {
    assert_eq!(stripe(&run(7, "busy", "running", &[])).1, rgb(night::RUNNING));
}

#[test]
fn a_passed_row_that_conflicts_has_a_stripe_in_the_conflict_colour() {
    let mut conflicting = passed();
    conflicting.trunk = Some(fun_ci_renderer::model::Trunk { branch_state: "conflicts".into(), trunk: "main".into() });

    assert_eq!(stripe(&conflicting).1, rgb(night::CONFLICT));
}

#[test]
fn a_passed_row_has_no_stripe() {
    assert_eq!(stripe(&passed()).0, "");
}

#[test]
fn a_failed_row_s_conflict_carries_its_stripe_down() {
    let mut conflicting = failed();
    conflicting.trunk = Some(fun_ci_renderer::model::Trunk { branch_state: "conflicts".into(), trunk: "main".into() });
    let grid = drawn(&Piece::Conflict(&conflicting), None, &[]);

    assert_eq!((grid.cells[0][COLUMNS.margin].text.as_str(), fg(&grid, COLUMNS.margin)), ("▌", rgb(night::FAILED)));
}
