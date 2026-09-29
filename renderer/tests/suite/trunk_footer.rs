//! The footer says, once and dim, which projects' trunks are stale
//! (design.md, The trunk).

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::art::output::Depth;
use fun_ci_renderer::grid::{Colour, Emulator, Grid};
use fun_ci_renderer::protocol::parse;
use fun_ci_renderer::replay::replay;

const RUN: &str = r#"{"id":1,"sha":"d4e5f67a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4","branch":"main","status":"passed","updated_at":1790000000,"stages":[]}"#;

/// The board drawn with `stale` as its `stale_trunks`.
fn drawn(stale: &str) -> Grid {
    let board = format!(r#"{{"t":"board","now":1790000000,"runs":[{RUN}],"stale_trunks":{stale}}}"#);
    let messages = [parse(&board).unwrap(), parse(r#"{"t":"tick","ms":100}"#).unwrap()];
    let frame = &replay(&messages, &Library::builtin(), (120, 24), Depth::TrueColour)[0];
    let mut terminal = Emulator::new(frame.size);
    terminal.feed(frame.size, &frame.bytes);
    terminal.grid()
}

fn footer(stale: &str) -> String {
    drawn(stale).text().lines().nth(16).unwrap().trim_end().to_string()
}

#[test]
fn the_footer_names_a_project_whose_trunk_was_fetched_long_ago() {
    assert_eq!(footer(r#"[{"project":"/src/app","since":1789989200}]"#),
               "  j/k move   c cancel   q quit   trunk stale: app, fetched 3h ago");
}

#[test]
fn the_footer_says_a_project_s_fetch_failed() {
    assert_eq!(footer(r#"[{"project":"/src/app","since":null}]"#),
               "  j/k move   c cancel   q quit   trunk stale: app, fetch failed");
}

#[test]
fn the_footer_names_each_stale_project() {
    assert!(footer(r#"[{"project":"/src/app","since":null},{"project":"/src/lib","since":null}]"#)
        .ends_with("trunk stale: app, fetch failed; lib, fetch failed"));
}

#[test]
fn the_stale_note_is_dim() {
    let grid = drawn(r#"[{"project":"/src/app","since":null}]"#);
    let column = grid.text().lines().nth(16).unwrap().find("trunk stale").unwrap();
    let cell = &grid.cells[16][column];
    assert_eq!((cell.fg, cell.attrs.clone()), (Colour::Default, vec!["dim"]));
}

#[test]
fn a_board_without_stale_trunks_has_the_plain_footer() {
    assert_eq!(footer("[]"), "  j/k move   c cancel   q quit");
}
