//! The table's other lines as they are drawn: a project's label and its
//! stale trunk, a conflict, a cut name, a line of passed branches, a count of
//! rows off the screen, and a flat row's project.

use crate::support::paint::{COLUMNS, NOW, WIDTH, at, drawn, failed, fg, frame, passed, rgb, run, text};
use fun_ci_renderer::grid::Emulator;
use fun_ci_renderer::model::StaleTrunk;
use fun_ci_renderer::table::night;
use fun_ci_renderer::table::paint::{Paint, paint};
use fun_ci_renderer::table::sections::sections;
use fun_ci_renderer::table::stack::Piece;
use serde_json::json;

#[test]
fn a_label_names_its_project_letter_spaced() {
    let runs = [failed()];
    let sections = sections(&runs);

    assert!(at(&drawn(&Piece::Label(&sections[0]), None, &[]), 12).starts_with("S T R I N G S - K A T A "));
}

#[test]
fn a_label_says_in_italics_when_its_stale_trunk_was_last_fetched() {
    let runs = [failed()];
    let sections = sections(&runs);
    let stale = [StaleTrunk { project: "/src/strings-kata".into(), since: Some(NOW - 7_200) }];
    let grid = drawn(&Piece::Label(&sections[0]), None, &stale);
    let column = text(&grid).find("trunk").unwrap();

    assert_eq!((at(&grid, column).trim_end().to_string(), grid.cells[0][column].attrs.clone()), ("trunk last fetched 2h ago".to_string(), vec!["italic"]));
}

#[test]
fn a_label_says_when_its_trunk_could_not_be_fetched() {
    let runs = [failed()];
    let sections = sections(&runs);
    let stale = [StaleTrunk { project: "/src/strings-kata".into(), since: None }];

    assert!(text(&drawn(&Piece::Label(&sections[0]), None, &stale)).contains("trunk could not be fetched"));
}

#[test]
fn a_conflict_is_said_in_italics_two_columns_into_the_name() {
    let mut run = failed();
    run.trunk = serde_json::from_value(json!({"branch_state": "conflicts", "trunk": "main"})).unwrap();
    let grid = drawn(&Piece::Conflict(&run), None, &[]);

    assert_eq!((at(&grid, 16).trim_end().to_string(), fg(&grid, 16)), ("conflicts with main".to_string(), rgb(night::CONFLICT)));
}

#[test]
fn a_branch_longer_than_its_room_is_cut_with_an_ellipsis() {
    let long = run(3, "refactor/extract-the-evidence-collector", "passed", &[]);

    assert!(at(&drawn(&Piece::Row(&long), None, &[]), 14).starts_with("refactor/extract… "));
}

#[test]
fn a_folded_line_names_each_passed_branch_with_its_age_then_says_passed() {
    let (one, two) = (passed(), run(4, "topic", "passed", &[]));
    let line = text(&drawn(&Piece::Folded(vec![&one, &two]), None, &[]));

    assert_eq!(line.split_whitespace().collect::<Vec<_>>(), ["main", "6m", "topic", "6m", "passed"]);
}

#[test]
fn a_cancelled_row_has_no_marks_and_says_how_many_runs_were_cancelled() {
    let mut run = run(5, "detached", "cancelled", &[]);
    run.folded = Some(3);

    assert_eq!(text(&drawn(&Piece::Row(&run), None, &[])).split("  ").map(str::trim).filter(|s| !s.is_empty()).collect::<Vec<_>>(), ["detached", "3 runs cancelled", "6m"]);
}

#[test]
fn rows_off_the_screen_below_are_counted_where_names_start() {
    assert!(at(&drawn(&Piece::More(4, true), None, &[]), 14).starts_with("… 4 more below"));
}

#[test]
fn rows_off_the_screen_above_are_counted_too() {
    assert!(text(&drawn(&Piece::More(1, false), None, &[])).contains("… 1 more above"));
}

#[test]
fn a_row_of_the_flat_layout_names_its_project_first_like_an_address() {
    let line = paint(&Piece::Row(&failed()), &Paint { columns: COLUMNS, frame: frame(), lead: None, stale: &[], paper: night::WINE, tags: Some(12) });
    let mut emulator = Emulator::new((WIDTH, 1));
    emulator.feed((WIDTH, 1), line.as_bytes());

    assert!(at(&emulator.grid(), 14).starts_with("strings-kata  feat "));
}

#[test]
fn a_folded_line_runs_on_past_the_rows_to_the_right_margin() {
    let names = ["feature-a", "feature-b", "feature-c", "feature-d", "feature-e"];
    let runs: Vec<_> = names.iter().enumerate().map(|(i, name)| run(10 + i as u64, name, "passed", &[])).collect();
    let line = text(&drawn(&Piece::Folded(runs.iter().collect()), None, &[]));

    assert!(!line.contains("more"), "{line}");
}

#[test]
fn a_folded_line_too_long_for_the_screen_says_passed_after_how_many_more() {
    let runs: Vec<_> = (0..12).map(|i| run(20 + i, &format!("feature/number-{i}"), "passed", &[])).collect();
    let line = text(&drawn(&Piece::Folded(runs.iter().collect()), None, &[]));

    assert!(line.contains(" more     passed"), "{line}");
}
