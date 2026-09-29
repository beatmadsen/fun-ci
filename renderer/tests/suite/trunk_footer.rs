//! The footer says, once and dim, which projects' trunks are stale
//! (design.md, The trunk).

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::art::output::Depth;
use fun_ci_renderer::grid::{Colour, Emulator, Grid};
use fun_ci_renderer::protocol::parse;
use fun_ci_renderer::replay::replay;
use fun_ci_renderer::table::palette;

const RUN: &str = r#"{"id":1,"sha":"d4e5f67a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4","branch":"main","status":"passed","updated_at":1790000000,"stages":[]}"#;

/// The board drawn with `stale` as its `stale_trunks`.
fn drawn(stale: &str) -> Grid {
    drawn_on(stale, 120)
}

fn drawn_on(stale: &str, cols: u16) -> Grid {
    let board = format!(r#"{{"t":"board","now":1790000000,"runs":[{RUN}],"stale_trunks":{stale}}}"#);
    let messages = [parse(&board).unwrap(), parse(r#"{"t":"tick","ms":100}"#).unwrap()];
    let frame = &replay(&messages, &Library::builtin(), (cols, 24), Depth::TrueColour)[0];
    let mut terminal = Emulator::new(frame.size);
    terminal.feed(frame.size, &frame.bytes);
    terminal.grid()
}

fn footer(stale: &str) -> String {
    drawn(stale).text().lines().nth(18).unwrap().trim_end().to_string()
}

#[test]
fn the_footer_names_a_project_whose_trunk_was_fetched_long_ago() {
    assert_eq!(footer(r#"[{"project":"/src/app","since":1789989200}]"#),
               "  j/k move   c cancel   q quit   app: trunk 3h old");
}

#[test]
fn the_footer_says_a_project_s_fetch_failed() {
    assert_eq!(footer(r#"[{"project":"/src/app","since":null}]"#),
               "  j/k move   c cancel   q quit   app: trunk fetch failed");
}

#[test]
fn the_footer_names_each_stale_project() {
    assert!(footer(r#"[{"project":"/src/app","since":null},{"project":"/src/lib","since":null}]"#)
        .ends_with("app: trunk fetch failed; lib: trunk fetch failed"));
}

#[test]
fn the_stale_note_is_grey_in_a_colour_no_state_uses() {
    let grid = drawn(r#"[{"project":"/src/app","since":null}]"#);
    let column = grid.text().lines().nth(18).unwrap().find("app: trunk").unwrap();
    let [r, g, b] = palette::SECONDARY;
    assert_eq!(grid.cells[18][column].fg, Colour::Rgb(r, g, b));
}

#[test]
fn a_stale_note_that_fits_is_not_cut_at_sixty_columns() {
    let line = drawn_on(r#"[{"project":"/src/agent-tome","since":1789992800}]"#, 60).text().lines().nth(18).unwrap().trim_end().to_string();
    assert!(line.ends_with("agent-tome: trunk 2h old"), "{line:?}");
}

#[test]
fn a_board_without_stale_trunks_has_the_plain_footer() {
    assert_eq!(footer("[]"), "  j/k move   c cancel   q quit");
}

#[test]
fn a_footer_too_long_for_the_terminal_ends_in_an_ellipsis() {
    let stale = r#"[{"project":"/src/app","since":null},{"project":"/src/library","since":null}]"#;
    let line = drawn_on(stale, 60).text().lines().nth(18).unwrap().trim_end().to_string();
    assert!(line.ends_with('…'), "{line:?}");
}

/// The footer of a board whose one run's long branch conflicts with main, on `cols` columns.
fn conflict_footer(cols: u16) -> String {
    conflict_footer_with(cols, "[]")
}

/// The same footer with `stale` as the board's `stale_trunks`.
fn conflict_footer_with(cols: u16, stale: &str) -> String {
    let run = r#"{"id":1,"sha":"d4e5f67a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4","branch":"feature/a-branch-name-long-enough-to-crowd-it","status":"failed","updated_at":1790000000,"stages":[],"trunk":{"branch_state":"conflicts","trunk":"main"}}"#;
    let board = format!(r#"{{"t":"board","now":1790000000,"runs":[{run}],"stale_trunks":{stale}}}"#);
    let messages = [parse(&board).unwrap(), parse(r#"{"t":"tick","ms":100}"#).unwrap()];
    let frame = &replay(&messages, &Library::builtin(), (cols, 24), Depth::TrueColour)[0];
    let mut terminal = Emulator::new(frame.size);
    terminal.feed(frame.size, &frame.bytes);
    terminal.grid().text().lines().nth(18).unwrap().trim_end().to_string()
}

#[test]
fn a_conflict_shown_as_a_zigzag_is_explained_in_the_footer() {
    assert!(conflict_footer(80).ends_with("↯ conflicts with trunk"), "{:?}", conflict_footer(80));
}

#[test]
fn a_conflict_said_in_words_needs_no_explaining() {
    assert!(!conflict_footer(200).contains('↯'), "{:?}", conflict_footer(200));
}

#[test]
fn the_zigzag_s_explanation_comes_before_a_stale_trunk_note() {
    let footer = conflict_footer_with(80, r#"[{"project":"/src/agent-tome","since":1789992800}]"#);
    assert!(footer.contains("↯ conflicts with trunk"), "{footer:?}");
}

#[test]
fn a_narrow_footer_gives_up_the_key_hints_before_the_notes() {
    let footer = conflict_footer_with(60, r#"[{"project":"/src/agent-tome","since":1789992800}]"#);
    assert_eq!(footer, "  q quit   ↯ conflicts with trunk   agent-tome: trunk 2h old");
}
