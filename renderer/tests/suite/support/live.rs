//! A scripted live session: inputs handed out in order, a clock the script
//! moves, and a record of every wait the session asked for.

use std::cell::{Cell, RefCell};
use std::collections::VecDeque;
use std::rc::Rc;
use std::time::Duration;

use fun_ci_renderer::animation::Library;
use fun_ci_renderer::console::Console;
use fun_ci_renderer::inputs::{Clock, Input, Inputs};
use fun_ci_renderer::session::{Session, run_live};
use serde_json::Value;

use super::FakeTerminal;

pub const HELLO: &str = r#"{"t":"hello","v":1}"#;

/// Hands out `inputs` in order, then `End`. A `FrameDue` moves the clock on
/// by the wait the session asked for, as a real timer would. Reading on after
/// `End` fails the test: a session that never stops would otherwise record
/// waits until memory runs out (a mutant of `Live::handle` once did).
struct Script {
    inputs: VecDeque<Input>,
    clock: Rc<Cell<u64>>,
    waits: Rc<RefCell<Vec<Option<Duration>>>>,
    ended: bool,
}

impl Script {
    fn advance_by(&self, wait: Option<Duration>) {
        let waited = wait.expect("a frame fell due with no timer set");
        self.clock.set(self.clock.get() + u64::try_from(waited.as_millis()).unwrap());
    }
}

impl Inputs for Script {
    fn next(&mut self, wait: Option<Duration>) -> Input {
        assert!(!self.ended, "the session asked for input after the end");
        self.waits.borrow_mut().push(wait);
        let input = self.inputs.pop_front().unwrap_or(Input::End);
        self.ended = input == Input::End;
        if input == Input::FrameDue {
            self.advance_by(wait);
        }
        input
    }
}

struct ScriptClock(Rc<Cell<u64>>);

impl Clock for ScriptClock {
    fn now_ms(&self) -> u64 {
        self.0.get()
    }
}

/// What a scripted session left behind.
pub struct Outcome {
    pub replies: Vec<Value>,
    pub frames: Vec<Vec<u8>>,
    pub waits: Vec<Option<Duration>>,
}

/// Runs `inputs` (after `hello`) through a live session on an 80x24 terminal.
pub fn live(inputs: Vec<Input>) -> Outcome {
    live_on((80, 24), inputs)
}

/// Runs `inputs` (after `hello`) through a live session on a terminal of `size`.
pub fn live_on(size: (u16, u16), inputs: Vec<Input>) -> Outcome {
    let (clock, waits) = (Rc::new(Cell::new(5_000)), Rc::new(RefCell::new(Vec::new())));
    let script = Script { inputs: [line(HELLO)].into_iter().chain(inputs).collect(), clock: clock.clone(), waits: waits.clone(), ended: false };
    let (mut output, mut terminal) = (Vec::new(), FakeTerminal::sized(size.0, size.1));
    let console = Console::new(&Library::builtin(), 0, (80, 24));
    run_live(Session { inputs: script, output: &mut output, clock: ScriptClock(clock), console }, &mut terminal);
    let replies = String::from_utf8(output).unwrap().lines().map(|l| serde_json::from_str(l).unwrap()).collect();
    Outcome { replies, frames: terminal.frames, waits: waits.take() }
}

pub fn line(text: &str) -> Input {
    Input::Line(text.to_string())
}

/// The replies after `ready`.
pub fn replies_after_ready(inputs: Vec<Input>) -> Vec<Value> {
    live(inputs).replies.into_iter().skip(1).collect()
}

/// The wait the session asked for after its last input.
pub fn last_wait(inputs: Vec<Input>) -> Option<Duration> {
    live(inputs).waits.pop().unwrap()
}

#[test]
#[should_panic(expected = "the session asked for input after the end")]
fn a_script_fails_a_session_that_reads_on_after_the_end() {
    let mut script = Script { inputs: VecDeque::new(), clock: Rc::default(), waits: Rc::default(), ended: false };
    script.next(None);
    script.next(None);
}
