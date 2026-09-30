//! The quiet table on a short screen, and its stale trunks (design.md, The
//! console): what it leaves out is counted, what needs you and its project
//! stay, and a stale trunk is said beside its label or on its own line.

use crate::support::quiet::{NOW, board, failed, passed, said, screen, screen_after, two_crowded_projects};
use serde_json::json;

#[test]
fn a_label_says_when_its_stale_trunk_was_last_fetched() {
    let mut board = board(&[failed(2, "feat", "/src/one"), passed(1, "main", "/src/two")], None);
    board["stale_trunks"] = json!([{"project": "/src/two", "since": NOW - 7_200}]);

    let text = screen_after(&board, 1, (120, 40)).text();
    let label = text.lines().find(|line| line.contains("T W O")).unwrap();

    assert!(label.trim_end().ends_with("trunk last fetched 2h ago"), "{label}");
}

#[test]
fn a_short_screen_says_how_many_passed_branches_it_left_out() {
    let grid = screen(&two_crowded_projects(), (80, 26));

    assert!(grid.text().lines().last().unwrap().contains("10 passed not shown"), "{}", grid.text());
}

#[test]
fn a_short_screen_keeps_the_failures_and_their_projects() {
    let lines = said(&screen(&two_crowded_projects(), (80, 26)));

    assert_eq!(lines[..4], ["O N E", "one-fix", "T W O", "two-fix"]);
}

#[test]
fn a_screen_too_short_for_labels_says_the_stale_trunk_on_its_own_line() {
    let mut board = board(&two_crowded_projects(), None);
    board["stale_trunks"] = json!([{"project": "/src/two", "since": NOW - 7_200}]);
    let grid = screen_after(&board, 1, (80, 22));

    assert!(grid.text().lines().any(|line| line.trim() == "two: trunk last fetched 2h ago"), "{}", grid.text());
}
