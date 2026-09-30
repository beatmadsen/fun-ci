//! How long a stage's effect keeps the console drawing at the busy rate: while
//! it plays, and not a frame past its end, or a board at rest would be drawn
//! ten times a second for good.

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::console::{Console, Moment};
use fun_ci_renderer::model::{Board, Event};

use crate::support::boards::{board, run};

fn failing() -> Console {
    let mut console = Console::new(&Library::builtin(), 0, (80, 24));
    console.show(&serde_json::from_str::<Board>(&board(&[run(1, "failed", &[("lint", "failed")])])).unwrap());
    console.queue(Event { name: "stage_failed".into(), run_id: Some(1), stage: Some("lint".into()), animation: None });
    console.frame(Moment { board_ms: 0, play_ms: 0 });
    console
}

#[test]
fn a_failure_keeps_the_console_busy_while_its_banner_plays() {
    let mut console = failing();
    console.frame(Moment { board_ms: 0, play_ms: 3_900 });

    assert!(console.busy());
}

#[test]
fn a_failure_leaves_the_console_at_rest_once_its_banner_has_played() {
    let mut console = failing();
    console.frame(Moment { board_ms: 0, play_ms: 4_000 });

    assert!(!console.busy());
}
