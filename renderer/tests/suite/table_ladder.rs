//! How the table fits a short screen (design.md, The console): it folds its
//! passed rows, then leaves the folded lines out and counts them, then closes
//! up the rows, then drops the labels; and when even that is too long, it
//! keeps the lead's row on screen and says how many rows it can't show.

use crate::support::pieces::kind;
use fun_ci_renderer::model::Run;
use fun_ci_renderer::table::ladder::fit;
use fun_ci_renderer::table::sections::sections;
use fun_ci_renderer::table::stack::Piece;
use serde_json::json;

fn run(id: u64, project: &str, status: &str) -> Run {
    serde_json::from_value(json!({"id": id, "sha": "0", "branch": format!("b{id}"), "project": project,
                                  "status": status, "updated_at": 0, "stages": []}))
    .unwrap()
}

/// Two projects, each with a failed branch and two passed ones.
fn board() -> Vec<Run> {
    vec![run(1, "/a", "failed"), run(2, "/a", "passed"), run(3, "/a", "passed"), run(4, "/b", "failed"), run(5, "/b", "passed"), run(6, "/b", "passed")]
}

fn kinds(room: usize, lead: Option<u64>) -> Vec<String> {
    let runs = board();
    let sections = sections(&runs);
    fit(&sections, lead, room, false).pieces.iter().map(kind).collect()
}

#[test]
fn a_table_with_room_keeps_every_row_and_its_air() {
    assert_eq!(kinds(40, None), ["blank", "label a", "blank", "row 1", "blank", "row 2", "blank", "row 3", "blank",
                                 "blank", "label b", "blank", "row 4", "blank", "row 5", "blank", "row 6", "blank"]);
}

#[test]
fn a_short_screen_folds_the_passed_rows_first() {
    assert_eq!(kinds(14, None), ["blank", "label a", "blank", "row 1", "blank", "folded 2", "blank", "blank", "label b", "blank", "row 4", "blank", "folded 2", "blank"]);
}

#[test]
fn a_shorter_screen_leaves_the_folded_lines_out() {
    assert_eq!(kinds(10, None), ["blank", "label a", "blank", "row 1", "blank", "blank", "label b", "blank", "row 4", "blank"]);
}

#[test]
fn what_a_short_screen_leaves_out_is_counted() {
    let runs = board();
    let sections = sections(&runs);

    assert_eq!(fit(&sections, None, 10, false).unshown, 4);
}

#[test]
fn a_shorter_screen_still_closes_up_the_rows_and_keeps_the_labels() {
    assert_eq!(kinds(6, None), ["blank", "label a", "row 1", "blank", "label b", "row 4"]);
}

#[test]
fn a_screen_too_short_for_the_labels_drops_them() {
    assert_eq!(kinds(2, None), ["row 1", "row 4"]);
}

/// Six failed branches of one project: nothing folds away.
fn troubled(room: usize, lead: Option<u64>) -> Vec<String> {
    let runs: Vec<Run> = (1..=6).map(|id| run(id, "/a", "failed")).collect();
    let sections = sections(&runs);
    fit(&sections, lead, room, false).pieces.iter().map(kind).collect()
}

#[test]
fn a_screen_too_short_even_then_keeps_the_lead_s_row_and_says_how_many_more_are_above() {
    assert_eq!(troubled(5, Some(6)), ["4 more above", "row 5", "top", "row 6", "bottom"]);
}

#[test]
fn a_screen_too_short_even_then_says_how_many_more_are_below() {
    assert_eq!(troubled(3, None), ["row 1", "row 2", "4 more below"]);
}

#[test]
fn a_calm_board_folds_a_project_s_passed_rows_even_with_room() {
    let runs = [run(1, "/a", "passed"), run(2, "/a", "passed"), run(3, "/b", "running")];
    let sections = sections(&runs);

    assert!(fit(&sections, None, 40, true).pieces.iter().any(|piece| matches!(piece, Piece::Folded(_))));
}
