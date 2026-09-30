//! The quiet table (design.md, The console), seen on the whole screen: each
//! project's branches under its name, one row per branch, what needs you in
//! one deep block, and a short branch's name whole on a narrow screen.

use crate::support::quiet::{board, failed, in_the_block, passed, run, said, screen, screen_with, stage};

#[test]
fn a_project_s_branches_sit_under_its_name_in_letter_spaced_capitals() {
    let runs = [failed(3, "feat", "/src/strings-kata"), passed(2, "main", "/src/strings-kata"), passed(1, "fix", "/src/agent-tome")];

    let lines = said(&screen(&runs, (120, 40)));

    assert_eq!(lines[..5], ["S T R I N G S - K A T A", "feat", "main", "A G E N T - T O M E", "fix"]);
}

#[test]
fn with_no_cursor_the_first_row_that_needs_you_sits_in_the_block() {
    let runs = [passed(3, "main", "/src/app"), failed(2, "feat", "/src/app"), failed(1, "fix", "/src/app")];

    assert_eq!(in_the_block(&screen(&runs, (120, 40))), ["feat"]);
}

#[test]
fn the_row_under_the_cursor_takes_the_block() {
    let runs = [failed(2, "feat", "/src/app"), passed(1, "main", "/src/app")];

    assert_eq!(in_the_block(&screen_with(&board(&runs, Some(1)), (120, 40))), ["main"]);
}

#[test]
fn a_board_where_nothing_needs_you_has_no_block() {
    let runs = [run(2, ("feat", "/src/app"), "running", &[stage("lint", "passed", 300)]), passed(1, "main", "/src/app")];

    assert!(in_the_block(&screen(&runs, (120, 40))).is_empty());
}

#[test]
fn on_sixty_columns_the_words_leave_a_short_branch_its_whole_name() {
    let runs = [failed(2, "fix/crash", "/src/app"), run(1, ("feature/login", "/src/app"), "running", &[stage("lint", "passed", 300)])];

    let lines = said(&screen(&runs, (60, 30)));

    assert!(lines.contains(&"fix/crash".to_string()), "{lines:?}");
}
