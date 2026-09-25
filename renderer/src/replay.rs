//! Headless replay of a scenario: one frame per `tick`.

use crate::animation::Library;
use crate::console::Console;
use crate::model::Board;
use crate::protocol::Inbound;

/// The bytes one tick wrote, the terminal size (cols, rows) they were drawn
/// for, the scenario time they were drawn at, and the header animation shown.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TickFrame {
    pub size: (u16, u16),
    pub elapsed_ms: u64,
    pub bytes: Vec<u8>,
    pub showing: String,
}

/// Draws a scenario on a terminal of `size` (cols, rows) until its first
/// `resize`, returning one frame per `tick`. Frame 1 includes the initial
/// screen clear.
#[must_use]
pub fn replay(messages: &[Inbound], library: &Library, size: (u16, u16)) -> Vec<TickFrame> {
    let mut replay = Replay { console: Console::new(library, 0, size), clock: Clock::default() };
    replay.console.clear();
    messages.iter().filter_map(|message| replay.apply(message)).collect()
}

struct Replay {
    console: Console,
    clock: Clock,
}

#[derive(Debug, Default)]
struct Clock {
    now_ms: i64,
    elapsed_ms: u64,
}

impl Replay {
    fn apply(&mut self, message: &Inbound) -> Option<TickFrame> {
        if let Inbound::Tick { ms } = message {
            return Some(self.tick(*ms));
        }
        self.absorb(message);
        None
    }

    fn absorb(&mut self, message: &Inbound) {
        match message {
            Inbound::Resize { cols, rows } => self.console.resize((*cols, *rows)),
            Inbound::Board(board) => self.show(board),
            Inbound::Event(event) => self.console.queue(event.clone()),
            _ => {}
        }
    }

    fn show(&mut self, board: &Board) {
        self.console.show(board);
        self.clock.now_ms = board.now * 1000;
    }

    fn tick(&mut self, ms: u64) -> TickFrame {
        self.clock.now_ms += i64::try_from(ms).unwrap_or(i64::MAX);
        self.clock.elapsed_ms += ms;
        let (bytes, showing) = self.console.frame(self.clock.now_ms);
        TickFrame { size: self.console.size(), elapsed_ms: self.clock.elapsed_ms, bytes, showing }
    }
}
