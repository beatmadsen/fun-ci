//! A change of colour depth reaches every cell: ratatui sends only the cells
//! that changed, so without drawing the screen again, what did not change
//! would stay in the old colours.

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::console::{Console, Moment};
use fun_ci_renderer::grid::{Colour, Emulator};
use fun_ci_renderer::model::Board;
use fun_ci_renderer::output::depth::Depth;

use crate::support::boards::{board, run};

const SIZE: (u16, u16) = (80, 24);

#[test]
fn a_new_colour_depth_redraws_the_cells_that_did_not_change() {
    let mut console = Console::new(&Library::builtin(), 0, SIZE);
    console.show(&serde_json::from_str::<Board>(&board(&[run(1, "passed", &[("lint", "passed")])])).unwrap());
    let mut emulator = Emulator::new(SIZE);
    emulator.feed(SIZE, &console.frame(Moment { board_ms: 0, play_ms: 0 }).0);
    console.set_depth(Depth::Xterm256);
    emulator.feed(SIZE, &console.frame(Moment { board_ms: 0, play_ms: 0 }).0);

    let grid = emulator.grid();
    let (row, column) = grid.text().lines().enumerate().find_map(|(y, line)| line.find("b1").map(|x| (y, x))).unwrap();
    assert!(matches!(grid.cells[row][column].fg, Colour::Idx(_)), "{:?}", grid.cells[row][column].fg);
}
