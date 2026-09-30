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

/// The colour of the first cell of `word` on screen below the header.
fn colour_of(grid: &Grid, word: &str) -> Colour {
    let text = grid.text();
    let (row, line) = text.lines().enumerate().skip(HEADER).find(|(_, line)| line.contains(word)).unwrap();
    grid.cells[row][line[..line.find(word).unwrap()].chars().count()].fg
}

#[test]
fn the_firefly_on_screen_is_no_brighter_than_the_passed_names_beside_it() {
    let grid = screen(&[passed(2, "feat", "/src/app"), passed(1, "main", "/src/app")], (120, 40));
    let flies = fireflies(&grid);

    assert!(flies.len() == 1 && brightness(flies[0]) <= brightness(colour_of(&grid, "feat")), "{flies:?}");
}

#[test]
fn a_board_with_a_run_still_running_has_no_firefly() {
    let runs = [run(2, ("feat", "/src/app"), "running", &[stage("lint", "passed", 300)]), passed(1, "main", "/src/app")];

    assert!(fireflies(&screen(&runs, (120, 40))).is_empty());
}

#[test]
fn the_block_breathes_lighter_over_two_seconds() {
    let board = board(&[failed(1, "feat", "/src/app")], None);

    let (first, later) = (paper(&screen_after(&board, 1, (120, 40))), paper(&screen_after(&board, 20, (120, 40))));

    assert!(brightness(later) > brightness(first), "{first:?} then {later:?}");
}

#[test]
fn when_nothing_needs_you_a_project_s_passed_branches_fold_into_one_line() {
    let runs = [passed(3, "feat", "/src/app"), passed(2, "fix", "/src/app"), passed(1, "main", "/src/app")];

    assert_eq!(said(&screen(&runs, (120, 40))).first().map(String::as_str), Some("feat 6m"));
}
