//! Headless replay of a scenario: one frame per `tick`.

use crate::animation::Library;
use crate::animator::{Animator, Cast};
use crate::board_view::BoardView;
use crate::model::Board;
use crate::protocol::Inbound;

/// The bytes one tick wrote, and the terminal size they were drawn for.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TickFrame {
    pub cols: u16,
    pub rows: u16,
    pub bytes: Vec<u8>,
}

/// Draws a scenario, returning one frame per `tick`. Frame 1 includes the
/// initial screen clear.
#[must_use]
pub fn replay(messages: &[Inbound], library: &Library) -> Vec<TickFrame> {
    let mut replay = Replay::new(library);
    replay.view.clear();
    messages.iter().filter_map(|message| replay.apply(message)).collect()
}

struct Replay {
    view: BoardView,
    board: Board,
    now_ms: i64,
    size: (u16, u16),
}

impl Replay {
    fn new(library: &Library) -> Self {
        let view = BoardView::new(Animator::new(Cast::new(library.clone(), 0)));
        Self { view, board: Board::default(), now_ms: 0, size: (80, 24) }
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
        self.now_ms = board.now * 1000;
    }

    fn tick(&mut self, ms: u64) -> TickFrame {
        self.now_ms += i64::try_from(ms).unwrap_or(i64::MAX);
        let (cols, rows) = self.size;
        self.view.begin_frame();
        self.view.resize(cols);
        self.view.render(&self.board, self.now_ms, rows);
        TickFrame { cols, rows, bytes: self.view.take() }
    }
}
