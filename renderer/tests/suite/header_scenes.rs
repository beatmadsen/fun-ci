//! The header paints its scene over the full width, as the scene is at the
//! time since it started, and all of it again after the terminal resizes.

use fun_ci_renderer::animation::{Library, Scene};
use fun_ci_renderer::art::canvas::Canvas;
use fun_ci_renderer::art::output::Depth;
use fun_ci_renderer::grid::{Colour, Grid};
use fun_ci_renderer::headless::emulate;
use fun_ci_renderer::protocol::{Inbound, parse};
use fun_ci_renderer::replay::{TickFrame, replay};
use serde_json::json;

use crate::support::boards::{TICK, board, run};

const RED: Colour = Colour::Rgb(128, 0, 0);
const BLUE: Colour = Colour::Rgb(0, 0, 128);

/// Half-bright red until 200 ms have passed, then half-bright blue; `length_ms` long.
#[derive(Debug)]
struct Turns(&'static str, Option<u64>);

impl Scene for Turns {
    fn name(&self) -> &'static str {
        self.0
    }

    fn length_ms(&self) -> Option<u64> {
        self.1
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        canvas.fill(|_, _| if t_ms < 200 { [0.5, 0.0, 0.0] } else { [0.0, 0.0, 0.5] });
    }
}

/// Red light twice as bright as the screen can show.
#[derive(Debug)]
struct Blinding;

impl Scene for Blinding {
    fn name(&self) -> &'static str {
        "running"
    }

    fn length_ms(&self) -> Option<u64> {
        None
    }

    fn paint(&self, canvas: &mut Canvas, _t_ms: u64) {
        canvas.fill(|_, _| [2.0, 0.0, 0.0]);
    }
}

static IDLE: Turns = Turns("idle", None);
static RUNNING: Blinding = Blinding;
static EXPLOSION: Turns = Turns("explosion", Some(300));

fn frames(lines: &[String], depth: Depth) -> Vec<TickFrame> {
    let mut library = Library::default();
    library.insert(&IDLE);
    library.insert(&EXPLOSION);
    library.insert(&RUNNING);
    let messages: Vec<Inbound> = lines.iter().map(|line| parse(line).unwrap()).collect();
    replay(&messages, &library, (80, 24), depth)
}

fn idle_then(ticks: usize) -> Vec<String> {
    [vec![board(&[])], vec![TICK.to_string(); ticks]].concat()
}

fn screen(lines: &[String]) -> Grid {
    emulate(&frames(lines, Depth::TrueColour)).pop().unwrap()
}

fn failure_then(ticks: usize) -> Vec<String> {
    let failed = board(&[run(1, "failed", &[("fast", "failed")])]);
    let event = json!({"t": "event", "name": "stage_failed", "run_id": 1, "stage": "fast"}).to_string();
    [vec![failed, event], vec![TICK.to_string(); ticks]].concat()
}

#[test]
fn should_paint_the_header_to_its_bottom_right_cell_when_a_scene_shows() {
    assert_eq!(screen(&idle_then(1)).cells[13][79].bg, RED);
}

#[test]
fn should_leave_the_row_below_the_header_unpainted() {
    assert_eq!(screen(&idle_then(1)).cells[14][0].bg, Colour::Default);
}

#[test]
fn should_show_a_scene_as_it_was_when_less_time_than_a_change_has_passed_since_it_started() {
    assert_eq!(screen(&idle_then(2)).cells[0][0].bg, RED);
}

#[test]
fn should_show_a_scene_as_it_is_now_when_enough_time_has_passed_since_it_started() {
    assert_eq!(screen(&idle_then(3)).cells[0][0].bg, BLUE);
}

#[test]
fn should_draw_the_whole_header_again_when_the_terminal_was_resized() {
    let lines = [idle_then(1), vec![json!({"t": "resize", "cols": 90, "rows": 24}).to_string(), TICK.to_string()]].concat();
    assert_eq!(screen(&lines).cells[0][89].bg, RED);
}

#[test]
fn should_play_the_failure_scene_when_a_stage_fails() {
    assert_eq!(frames(&failure_then(1), Depth::TrueColour)[0].showing, "explosion");
}

#[test]
fn should_return_to_the_idle_scene_when_the_failure_scene_has_played_its_length() {
    assert_eq!(frames(&failure_then(5), Depth::TrueColour)[4].showing, "idle");
}

#[test]
fn should_draw_in_the_nearest_xterm_colours_when_limited_to_256() {
    assert_eq!(emulate(&frames(&idle_then(1), Depth::Xterm256)).pop().unwrap().cells[0][0].bg, Colour::Idx(88));
}

#[test]
fn should_turn_light_brighter_than_the_screen_towards_white_when_it_draws_a_scene() {
    let running = [board(&[run(1, "running", &[("fast", "running")])]), TICK.to_string()];
    assert_eq!(screen(&running).cells[0][0].bg, Colour::Rgb(255, 89, 89));
}
