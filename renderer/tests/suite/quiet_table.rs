//! The quiet table (design.md, The console), seen on the whole screen: each
//! project's branches under its name, one row per branch, what needs you in
//! one deep block, and a short branch's name whole on a narrow screen.

use crate::support::quiet::{board, failed, in_the_block, passed, run, said, screen, screen_with, stage, two_crowded_projects};

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

/// The legend's lines on `screen`, trimmed.
fn legend_lines(screen: &fun_ci_renderer::grid::Grid) -> Vec<String> {
    screen.text().lines().map(str::trim).filter(|line| crate::support::quiet::legend(line)).map(str::to_string).collect()
}

#[test]
fn a_legend_names_each_stage_over_its_mark_and_says_what_it_is_for() {
    let runs = [failed(3, "feat", "/src/strings-kata")];

    assert_eq!(legend_lines(&screen(&runs, (120, 40))), [
        "lint · checks the code without running it",
        "│ build · compiles the code and its tests",
        "│ │ fast suite · quick tests, after lint and the build",
        "│ │ │ slow suite · long tests, run in the background",
    ]);
}

#[test]
fn each_stage_s_name_in_the_legend_sits_over_its_mark() {
    let runs = [failed(3, "feat", "/src/strings-kata")];
    let text = screen(&runs, (120, 40)).text();
    let lines: Vec<&str> = text.lines().collect();
    let column = |line: &str, found: &str| line[..line.find(found).unwrap()].chars().count();
    let marks = lines.iter().find(|line| line.contains("feat")).unwrap();
    let slow = lines.iter().find(|line| line.contains("slow suite")).unwrap();

    assert_eq!(column(slow, "slow suite"), column(marks, "✓─✓─◆") + 6);
}

#[test]
fn a_screen_too_narrow_for_what_the_stages_are_for_still_names_them() {
    let runs = [failed(3, "feat", "/src/strings-kata")];

    assert_eq!(legend_lines(&screen(&runs, (60, 30))).last().map(String::as_str), Some("│ │ │ slow suite"));
}

#[test]
fn a_short_screen_folds_its_passed_rows_to_keep_the_legend() {
    let grid = screen(&two_crowded_projects(), (120, 36));

    assert_eq!((legend_lines(&grid).len(), said(&grid).contains(&"✓ one-1 6m".to_string())), (4, true), "{}", grid.text());
}

#[test]
fn a_screen_that_would_leave_rows_out_for_the_legend_says_it_on_one_line_above_the_footer() {
    let grid = screen(&two_crowded_projects(), (120, 30));
    let above_footer = grid.text().lines().rev().nth(1).unwrap_or_default().trim().to_string();

    assert_eq!((legend_lines(&grid).len(), above_footer.as_str()), (0, fun_ci_renderer::table::legend::KEY), "{}", grid.text());
}

#[test]
fn a_narrow_screen_says_the_legend_briefly_on_one_line() {
    let grid = screen(&two_crowded_projects(), (60, 30));

    assert!(grid.text().contains(fun_ci_renderer::table::legend::KEY_BRIEFLY), "{}", grid.text());
}

#[test]
fn a_screen_too_short_for_the_legend_and_the_rows_gives_the_legend_up() {
    assert!(legend_lines(&screen(&two_crowded_projects(), (80, 22))).is_empty());
}

#[test]
fn a_legend_describes_every_stage_or_none() {
    let runs = [failed(3, "a-rather-long-branch-name-here", "/src/strings-kata")];
    let lines = legend_lines(&screen(&runs, (100, 40)));

    assert_eq!(lines.iter().filter(|line| line.contains(" · ")).count() % 4, 0, "{lines:?}");
}
