//! What the table is made of, top to bottom, before it is drawn: blank lines,
//! a label per project, a row per branch and what goes with it.

use fun_ci_renderer::model::Run;
use fun_ci_renderer::table::sections::sections;
use fun_ci_renderer::table::stack::{Fold, Piece, Rung, stack};
use serde_json::json;

fn run(id: u64, project: &str, status: &str) -> Run {
    serde_json::from_value(json!({"id": id, "sha": format!("{id:040}"), "branch": format!("b{id}"),
                                  "project": project, "status": status, "updated_at": 0, "stages": []}))
    .unwrap()
}

fn kinds(runs: &[Run], step: Rung) -> Vec<String> {
    led(runs, None, step)
}

fn led(runs: &[Run], lead: Option<u64>, step: Rung) -> Vec<String> {
    let sections = sections(runs);
    stack(&sections, lead, step).iter().map(kind).collect()
}

fn conflicting(id: u64) -> Run {
    let mut run = run(id, "/a", "passed");
    run.trunk = serde_json::from_value(json!({"branch_state": "conflicts", "trunk": "main"})).unwrap();
    run
}

fn kind(piece: &Piece) -> String {
    match piece {
        Piece::Blank => "blank".into(),
        Piece::Label(section) => format!("label {}", section.project),
        Piece::Row(run) => format!("row {}", run.id),
        Piece::Conflict(run) => format!("conflict {}", run.id),
        Piece::Edge(top) => (if *top { "top" } else { "bottom" }).into(),
        Piece::Folded(runs) => format!("folded {}", runs.len()),
        Piece::More(count, _) => format!("{count} more"),
    }
}

const SPACED: Rung = Rung { gap: true, labels: true, fold: Fold::Never, passed: true };
const TIGHT: Rung = Rung { gap: false, ..SPACED };
const FOLDED: Rung = Rung { fold: Fold::All, ..SPACED };
const FLAT: Rung = Rung { labels: false, ..SPACED };

#[test]
fn a_spaced_table_opens_each_project_with_a_blank_line_and_its_label() {
    let runs = [run(1, "/a", "passed"), run(2, "/b", "passed")];

    assert_eq!(kinds(&runs, SPACED), ["blank", "label a", "blank", "row 1", "blank", "blank", "label b", "blank", "row 2", "blank"]);
}

#[test]
fn a_table_of_one_project_has_no_label() {
    let runs = [run(1, "/a", "passed"), run(2, "/a", "passed")];

    assert_eq!(kinds(&runs, SPACED), ["blank", "row 1", "blank", "row 2", "blank"]);
}

#[test]
fn the_lead_row_sits_between_the_block_s_edges_in_place_of_the_blank_before_it() {
    let runs = [run(1, "/a", "failed"), run(2, "/a", "passed")];

    assert_eq!(led(&runs, Some(1), SPACED), ["top", "row 1", "bottom", "row 2", "blank"]);
}

#[test]
fn a_row_whose_branch_conflicts_with_the_trunk_is_followed_by_the_conflict() {
    assert_eq!(kinds(&[conflicting(1)], SPACED), ["blank", "row 1", "conflict 1", "blank"]);
}

#[test]
fn the_lead_s_conflict_is_inside_the_block() {
    assert_eq!(led(&[conflicting(1)], Some(1), SPACED), ["top", "row 1", "conflict 1", "bottom"]);
}

#[test]
fn a_tight_table_leaves_no_blank_line_between_rows() {
    let runs = [run(1, "/a", "passed"), run(2, "/a", "passed"), run(3, "/b", "passed")];

    assert_eq!(kinds(&runs, TIGHT), ["blank", "label a", "row 1", "row 2", "blank", "label b", "row 3"]);
}

#[test]
fn folding_puts_a_project_s_passed_rows_on_one_line_after_its_others() {
    let runs = [run(1, "/a", "passed"), run(2, "/a", "failed"), run(3, "/a", "passed")];

    assert_eq!(kinds(&runs, FOLDED), ["blank", "row 2", "blank", "folded 2", "blank"]);
}

#[test]
fn folding_keeps_the_lead_s_row() {
    let runs = [run(1, "/a", "passed"), run(2, "/a", "passed")];

    assert_eq!(led(&runs, Some(1), FOLDED), ["top", "row 1", "bottom", "folded 1", "blank"]);
}

#[test]
fn folding_keeps_the_row_of_a_passed_branch_that_conflicts_with_the_trunk() {
    let runs = [conflicting(1), run(2, "/a", "passed")];

    assert_eq!(kinds(&runs, FOLDED), ["blank", "row 1", "conflict 1", "blank", "folded 1", "blank"]);
}

#[test]
fn resting_folds_only_a_project_with_two_passed_rows_or_more() {
    let runs = [run(1, "/a", "passed"), run(2, "/a", "passed"), run(3, "/b", "passed")];
    let resting = Rung { fold: Fold::Many, ..SPACED };

    assert_eq!(kinds(&runs, resting), ["blank", "label a", "blank", "folded 2", "blank", "blank", "label b", "blank", "row 3", "blank"]);
}

#[test]
fn without_passed_lines_the_folded_line_is_left_out() {
    let runs = [run(1, "/a", "failed"), run(2, "/a", "passed")];

    assert_eq!(kinds(&runs, Rung { passed: false, ..FOLDED }), ["blank", "row 1", "blank"]);
}

#[test]
fn a_flat_table_has_neither_labels_nor_a_blank_line_on_top() {
    let runs = [run(1, "/a", "passed"), run(2, "/b", "passed")];

    assert_eq!(kinds(&runs, FLAT), ["row 1", "blank", "row 2", "blank"]);
}
