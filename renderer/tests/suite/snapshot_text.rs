//! The snapshot text: the header as a digest of its cells, the rest as text
//! and a letter per cell style.

use fun_ci_renderer::grid::{Emulator, Grid};

use crate::support::snapshot::render;

fn screen(bytes: &str) -> Grid {
    let mut emulator = Emulator::new((4, 16));
    emulator.feed((4, 16), bytes.as_bytes());
    emulator.grid()
}

const RED_CORNER: &str = "\u{1b}[48;2;255;0;0m \u{1b}[0m";
const REDDER_CORNER: &str = "\u{1b}[48;2;254;0;0m \u{1b}[0m";
const BELOW_HEADER: &str = "\u{1b}[15;1Hok";

#[test]
fn should_change_the_header_digest_when_one_header_cell_changes_colour() {
    assert_ne!(render(&[screen(RED_CORNER)]), render(&[screen(REDDER_CORNER)]));
}

#[test]
fn should_write_the_rows_below_the_header_as_text() {
    assert!(render(&[screen(BELOW_HEADER)]).contains("\n  |ok\n"));
}

#[test]
fn should_leave_the_header_out_of_the_text_rows() {
    assert!(!render(&[screen("hey")]).contains("hey"));
}
