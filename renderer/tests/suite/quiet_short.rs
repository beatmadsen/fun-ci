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

#[test]
fn a_screen_too_short_for_labels_names_each_row_s_project_first() {
    let text = screen(&two_crowded_projects(), (80, 22)).text();

    assert!(text.lines().any(|line| line.trim_start().starts_with("one  one-fix")), "{text}");
}

#[test]
fn a_flat_screen_of_one_project_names_no_project() {
    let runs: Vec<_> = two_crowded_projects().into_iter().take(6).collect();
    let text = screen(&runs, (80, 18)).text();

    assert!(text.lines().any(|line| line.trim_start().starts_with("one-fix")), "{text}");
}

#[test]
fn a_flat_row_on_a_screen_with_no_room_to_spare_keeps_its_whole_branch_name() {
    let text = screen(&two_crowded_projects(), (72, 22)).text();

    assert!(text.lines().any(|line| line.trim_start().starts_with("one  one-fix ")), "{text}");
}

/// The blank columns between `name` and what follows it on its row.
fn space_after(text: &str, name: &str) -> usize {
    let row = text.lines().find(|line| line.contains(name)).unwrap();
    let after = &row[row.find(name).unwrap() + name.len()..];
    after.len() - after.trim_start().len()
}

#[test]
fn a_flat_row_keeps_as_much_space_before_its_marks_as_a_labelled_one() {
    let (labelled, flat) = (screen(&two_crowded_projects(), (120, 40)).text(), screen(&two_crowded_projects(), (120, 22)).text());

    assert_eq!(space_after(&flat, "one  one-fix"), space_after(&labelled, "one-fix"));
}
