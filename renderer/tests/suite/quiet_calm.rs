//! The quiet table at rest (design.md, The console): the block breathes, a
//! project's passed branches fold when nothing needs you, and a board where
//! everything passed gets one dim firefly.

use crate::support::quiet::{HEADER, board, failed, paper, passed, run, said, screen, screen_after, stage};
use fun_ci_renderer::grid::{Colour, Grid};

/// Each `•` on screen below the header, with its colour.
fn fireflies(grid: &Grid) -> Vec<Colour> {
    grid.cells.iter().skip(HEADER).flat_map(|row| row.iter().filter(|cell| cell.text == "•").map(|cell| cell.fg)).collect()
}

fn brightness(colour: Colour) -> u32 {
    match colour {
        Colour::Rgb(r, g, b) => u32::from(r) + u32::from(g) + u32::from(b),
        _ => 0,
    }
}

#[test]
fn a_board_where_everything_passed_has_one_firefly_below_the_table() {
    let runs = [passed(2, "feat", "/src/app"), passed(1, "main", "/src/app")];

    assert_eq!(fireflies(&screen(&runs, (120, 40))).len(), 1);
}

#[test]
fn the_firefly_is_no_brighter_than_a_passed_branch_s_name() {
    let runs = [passed(2, "feat", "/src/app"), passed(1, "main", "/src/app")];
    let [r, g, b] = fun_ci_renderer::table::night::pale(fun_ci_renderer::table::night::BRANCH);

    assert!(fireflies(&screen(&runs, (120, 40))).into_iter().all(|fly| brightness(fly) <= brightness(Colour::Rgb(r, g, b))));
}

#[test]
fn a_board_with_a_run_still_running_has_no_firefly() {
    let runs = [run(2, ("feat", "/src/app"), "running", &[stage("lint", "passed", 300)]), passed(1, "main", "/src/app")];

    assert!(fireflies(&screen(&runs, (120, 40))).is_empty());
}

#[test]
fn the_block_breathes_lighter_over_two_seconds() {
    let board = board(&[failed(1, "feat", "/src/app")], None);

    assert_ne!(paper(&screen_after(&board, 1, (120, 40))), paper(&screen_after(&board, 20, (120, 40))));
}

#[test]
fn when_nothing_needs_you_a_project_s_passed_branches_fold_into_one_line() {
    let runs = [passed(3, "feat", "/src/app"), passed(2, "fix", "/src/app"), passed(1, "main", "/src/app")];

    assert_eq!(said(&screen(&runs, (120, 40))).first().map(String::as_str), Some("feat 6m"));
}
