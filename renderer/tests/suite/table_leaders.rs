//! Which lines of the table the legend's leaders run down (design.md, The
//! console): the blank lines from the legend down to the last project's
//! last line, and across the rule of each project's label between, so each column of marks hangs from
//! its stage's name in every project; never a row, a block's edge, a
//! conflict, a folded line or a count.

use fun_ci_renderer::model::Run;
use fun_ci_renderer::table::leaders::Leaders;
use fun_ci_renderer::table::sections::sections;
use fun_ci_renderer::table::stack::{Fold, Rung, stack, with_legend};
use serde_json::json;

fn run(id: u64, project: &str, status: &str) -> Run {
    serde_json::from_value(json!({"id": id, "sha": "0", "branch": format!("b{id}"), "project": project,
                                  "status": status, "updated_at": 0, "stages": []}))
    .unwrap()
}

const SPACED: Rung = Rung { gap: true, labels: true, fold: Fold::Never, passed: true };

fn leaders(runs: &[Run], lead: Option<u64>) -> Leaders {
    let sections = sections(runs);
    Leaders::over(&with_legend(stack(&sections, lead, SPACED)), 30).unwrap()
}

fn lines(runs: &[Run], lead: Option<u64>) -> Vec<u16> {
    leaders(runs, lead).lines
}

#[test]
fn leaders_run_down_every_blank_line_from_the_legend_to_the_last_row() {
    // blank, legend x4, blank, label a, blank, row 1, blank, blank, label b, blank, row 2, blank
    assert_eq!(lines(&[run(1, "/a", "passed"), run(2, "/b", "passed")], None), [5, 7, 9, 10, 12]);
}

#[test]
fn leaders_cross_each_project_s_label_line() {
    assert_eq!(leaders(&[run(1, "/a", "passed"), run(2, "/b", "passed")], None).labels, [6, 11]);
}

#[test]
fn leaders_skip_the_lead_s_block_and_its_conflict() {
    let mut conflicting = run(1, "/a", "failed");
    conflicting.trunk = serde_json::from_value(json!({"branch_state": "conflicts", "trunk": "main"})).unwrap();
    // blank, legend x4, blank, label a, top, row 1, conflict 1, bottom, blank, label b, blank, row 2, blank
    assert_eq!(lines(&[conflicting, run(2, "/b", "passed")], Some(1)), [5, 11, 13]);
}

#[test]
fn leaders_skip_a_line_of_folded_branches() {
    let runs = [run(1, "/a", "failed"), run(2, "/a", "passed"), run(3, "/a", "passed")];
    let sections = sections(&runs);
    let pieces = with_legend(stack(&sections, None, Rung { fold: Fold::All, ..SPACED }));
    // blank, legend x4, blank, row 1, blank, folded 2, blank
    assert!(!Leaders::over(&pieces, 30).unwrap().lines.contains(&8));
}

#[test]
fn a_table_without_a_legend_has_no_leaders() {
    let runs = [run(1, "/a", "passed")];
    let sections = sections(&runs);

    assert_eq!(Leaders::over(&stack(&sections, None, SPACED), 30), None);
}

#[test]
fn leaders_start_at_the_column_of_the_first_mark() {
    let runs = [run(1, "/a", "passed")];
    let sections = sections(&runs);

    assert_eq!(Leaders::over(&with_legend(stack(&sections, None, SPACED)), 30).map(|leaders| leaders.column), Some(30));
}

#[test]
fn leaders_are_the_legend_s_own_lines_colour() {
    let runs = [run(1, "/a", "passed")];
    let sections = sections(&runs);

    assert_eq!(Leaders::over(&with_legend(stack(&sections, None, SPACED)), 30).map(|leaders| leaders.colour), Some(fun_ci_renderer::table::leaders::colour()));
}


#[test]
fn leaders_run_down_past_projects_whose_branches_are_folded() {
    let runs = [run(1, "/a", "failed"), run(2, "/b", "passed"), run(3, "/b", "passed")];
    let sections = sections(&runs);
    let pieces = with_legend(stack(&sections, Some(1), Rung { fold: Fold::All, ..SPACED }));
    let leaders = Leaders::over(&pieces, 30).unwrap();
    // blank, legend x4, blank, label a, top, row 1, bottom, blank, label b, blank, folded 2, blank
    assert_eq!((leaders.lines, leaders.labels), (vec![5, 10, 12], vec![6, 11]));
}
