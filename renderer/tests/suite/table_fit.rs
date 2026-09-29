//! The table fits its terminal: nothing is drawn past the last column, where
//! a terminal would wrap it onto the next line and push the board up, and the
//! newest run sits right under the header. Checked on the busy board, whose
//! long branch names and conflict markers are what overflowed, at the widths
//! the console supports.

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::art::output::Depth;
use fun_ci_renderer::grid::{Emulator, Grid};
use fun_ci_renderer::protocol::Inbound;
use fun_ci_renderer::replay::replay;
use fun_ci_renderer::scenario;

use crate::support::contract_dir;

const ROWS: u16 = 40;
/// Columns the emulator has beyond the terminal's, to catch what spills.
const SPARE: u16 = 40;

/// The busy board's last screen, drawn for a terminal `width` wide on one
/// `spare` columns wider.
fn last_screen(width: u16, spare: u16) -> Grid {
    let path = contract_dir().join("scenarios").join("busy-board.jsonl");
    let messages: Vec<Inbound> =
        scenario::load(&path).unwrap().into_iter().filter(|m| !matches!(m, Inbound::Resize { .. })).collect();
    let mut emulator = Emulator::new((width + spare, ROWS));
    for frame in replay(&messages, &Library::builtin(), (width, ROWS), Depth::TrueColour) {
        emulator.feed((width + spare, ROWS), &frame.bytes);
    }
    emulator.grid()
}

/// Every non-blank cell past the terminal's last column, as (row, column).
fn spilled(width: u16) -> Vec<(usize, usize)> {
    let grid = last_screen(width, SPARE);
    let mut spilled = Vec::new();
    for (row, cells) in grid.cells.iter().enumerate() {
        let drawn = cells.iter().enumerate().skip(usize::from(width)).filter(|(_, c)| !c.text.trim().is_empty());
        spilled.extend(drawn.map(|(col, _)| (row, col)));
    }
    spilled
}

/// The first run's line, under the 14-row header, a blank line and the stages' names, on a terminal just `width` wide.
fn first_row(width: u16) -> String {
    last_screen(width, 0).text().lines().nth(16).unwrap_or_default().to_string()
}

macro_rules! widths {
    ($($fits:ident, $newest:ident: $width:literal;)*) => {
        $(
            #[test]
            fn $fits() {
                assert_eq!(spilled($width), vec![]);
            }

            #[test]
            fn $newest() {
                assert!(first_row($width).contains("feat/search"), "{:?}", first_row($width));
            }
        )*
    };
}

widths! {
    nothing_is_drawn_past_sixty_columns, the_newest_run_is_under_the_header_at_sixty_columns: 60;
    nothing_is_drawn_past_eighty_columns, the_newest_run_is_under_the_header_at_eighty_columns: 80;
    nothing_is_drawn_past_a_hundred_and_twenty_columns, the_newest_run_is_under_the_header_at_a_hundred_and_twenty_columns: 120;
    nothing_is_drawn_past_two_hundred_columns, the_newest_run_is_under_the_header_at_two_hundred_columns: 200;
}
