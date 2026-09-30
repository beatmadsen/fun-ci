//! When a frame clears the screen: one after a clear asked for, a resize or a
//! change of colour depth does, once however many of them came together; any
//! other frame writes only the cells that changed, since a screen cleared
//! every frame flickers. (The first frame's clear is asked for by the live
//! session and the replay: `board_layout.rs`.)

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::console::{Console, Moment};
use fun_ci_renderer::model::Board;

use crate::support::boards::{board, run};

const CLEAR: &str = "\u{1b}[2J";
const AT: Moment = Moment { board_ms: 0, play_ms: 0 };

fn console() -> Console {
    let mut console = Console::new(&Library::builtin(), 0, (80, 24));
    console.show(&serde_json::from_str::<Board>(&board(&[run(1, "passed", &[("lint", "passed")])])).unwrap());
    console
}

fn clears(bytes: &[u8]) -> usize {
    String::from_utf8_lossy(bytes).matches(CLEAR).count()
}

#[test]
fn a_frame_with_nothing_new_to_clear_for_clears_nothing() {
    let mut console = console();
    console.frame(AT);

    assert_eq!(clears(&console.frame(AT).0), 0);
}

#[test]
fn a_clear_and_a_resize_before_one_frame_clear_it_once() {
    let mut console = console();
    console.frame(AT);
    console.clear();
    console.resize((100, 30));

    assert_eq!(clears(&console.frame(AT).0), 1);
}

#[test]
fn a_clear_asked_for_clears_the_next_frame() {
    let mut console = console();
    console.frame(AT);
    console.clear();

    assert_eq!(clears(&console.frame(AT).0), 1);
}
