//! A differential failure names where the two screens first differ.

use fun_ci_renderer::grid::{Emulator, Grid};

fn screen(size: (u16, u16), bytes: &str) -> Grid {
    let mut emulator = Emulator::new(size);
    emulator.feed(size, bytes.as_bytes());
    emulator.grid()
}

fn difference(a: &str, b: &str) -> String {
    let found = screen((4, 3), a).first_difference(&screen((4, 3), b)).unwrap();
    found.lines().next().unwrap().split(':').next().unwrap().to_string()
}

#[test]
fn identical_screens_have_no_difference() {
    assert_eq!(screen((4, 3), "ab").first_difference(&screen((4, 3), "ab")), None);
}

#[test]
fn a_difference_is_located_by_row_and_column() {
    assert_eq!(difference("abcd\r\nefgh\r\nijkl", "abcd\r\nefXh\r\nijkl"), "row 2 col 3");
}

#[test]
fn a_difference_in_the_last_column_is_located() {
    assert_eq!(difference("abcd\r\nefgh", "abcd\r\nefgX"), "row 2 col 4");
}

#[test]
fn a_difference_in_the_first_cell_is_located() {
    assert_eq!(difference("abcd", "Xbcd"), "row 1 col 1");
}

#[test]
fn screens_of_different_sizes_differ_in_size() {
    let found = screen((4, 3), "").first_difference(&screen((5, 3), "")).unwrap();
    assert_eq!(found, "size 4x3 vs 5x3");
}

#[test]
fn the_difference_shows_both_screens() {
    let found = screen((4, 1), "abcd").first_difference(&screen((4, 1), "abXd")).unwrap();
    assert_eq!(found.lines().skip(1).collect::<Vec<_>>(), ["abcd", "---", "abXd"]);
}
