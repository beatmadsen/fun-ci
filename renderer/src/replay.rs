//! Headless replay of a scenario: one frame per `tick`.

use crate::animation::Library;
use crate::animator::{Animator, Cast};
use crate::board_view::BoardView;
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
    let mut replay = Replay::new(library, size);
    replay.view.clear();
    messages.iter().filter_map(|message| replay.apply(message)).collect()
}

struct Replay {
    view: BoardView,
    board: Board,
    clock: Clock,
    size: (u16, u16),
}

#[derive(Debug, Default)]
struct Clock {
    now_ms: i64,
    elapsed_ms: u64,
}

impl Replay {
    fn new(library: &Library, size: (u16, u16)) -> Self {
        let view = BoardView::new(Animator::new(Cast::new(library.clone(), 0)));
        Self { view, board: Board::default(), clock: Clock::default(), size }
    }

    fn apply(&mut self, message: &Inbound) -> Option<TickFrame> {
        if let Inbound::Tick { ms } = message {
            return Some(self.tick(*ms));
        }
        self.absorb(message);
        None
    }

    fn absorb(&mut self, message: &Inbound) {
        match message {
            Inbound::Resize { cols, rows } => self.size = (*cols, *rows),
            Inbound::Board(board) => self.show(board),
            Inbound::Event(event) => self.view.animator().queue(event.clone()),
            _ => {}
        }
    }

    fn show(&mut self, board: &Board) {
        self.board = board.clone();
        self.clock.now_ms = board.now * 1000;
    }

    fn tick(&mut self, ms: u64) -> TickFrame {
        self.clock.now_ms += i64::try_from(ms).unwrap_or(i64::MAX);
        self.clock.elapsed_ms += ms;
        self.view.begin_frame();
        self.view.resize(self.size.0);
        let showing = self.view.render(&self.board, self.clock.now_ms, self.size.1);
        TickFrame { size: self.size, elapsed_ms: self.clock.elapsed_ms, bytes: self.view.take(), showing }
    }
}
