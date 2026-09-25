//! The live console: one input at a time, drawing on the terminal on its
//! own clock and telling Ruby about keys and resizes.

use std::io::Write;
use std::time::Duration;

use crate::console::Console;
use crate::inputs::{Clock, Input, Inputs};
use crate::keys;
use crate::model::Board;
use crate::protocol::{Inbound, Outbound, parse};
use crate::session::{EXIT_OK, Entered, Replies};
use crate::terminal::Terminal;

/// Frame interval while anything animates or runs.
const BUSY_MS: u64 = 100;
/// Frame interval otherwise, for relative times.
const IDLE_MS: u64 = 1000;

/// The console on show, the clock it is drawn by, the board time the clock
/// was set to, and when the last frame was drawn.
pub struct Live<C: Clock> {
    console: Console,
    clock: C,
    anchor: Anchor,
    last_frame: Option<u64>,
}

/// The latest board's `now`, in milliseconds, and the wall time it arrived.
#[derive(Debug, Default, Clone, Copy)]
struct Anchor {
    board_ms: i64,
    wall_ms: u64,
}

impl<C: Clock> Live<C> {
    #[must_use]
    pub fn new(console: Console, clock: C) -> Self {
        Self { console, clock, anchor: Anchor::default(), last_frame: None }
    }

    /// Handles inputs until `quit` or the end of Ruby's input. Frames are
    /// drawn at the terminal's size, the first one clearing the screen.
    pub fn converse<I: Inputs, W: Write, T: Terminal>(
        mut self,
        inputs: &mut I,
        replies: &mut Replies<W>,
        entered: &mut Entered<T>,
    ) -> i32 {
        self.console.resize(entered.terminal().size());
        self.console.clear();
        while self.handle(inputs.next(self.wait()), replies, entered.terminal()) {}
        EXIT_OK
    }

    /// Handles one input; false when the session is over.
    fn handle<W: Write, T: Terminal>(&mut self, input: Input, replies: &mut Replies<W>, terminal: &mut T) -> bool {
        match input {
            Input::Line(line) => return self.receive(&line, replies, terminal),
            Input::Keys(bytes) => keys::decode(&bytes).iter().for_each(|key| replies.send(&Outbound::key(key))),
            Input::Resize { cols, rows } => self.resize((cols, rows), replies, terminal),
            Input::FrameDue => self.draw(terminal),
            Input::End => return false,
        }
        true
    }

    fn receive<W: Write, T: Terminal>(&mut self, line: &str, replies: &mut Replies<W>, terminal: &mut T) -> bool {
        match parse(line) {
            Ok(Inbound::Quit) => return false,
            Ok(Inbound::Board(board)) => self.show(&board, terminal),
            Ok(Inbound::Event(event)) => self.console.queue(event),
            Ok(_) => {}
            Err(error) => replies.send(&error.reply()),
        }
        true
    }

    fn show<T: Terminal>(&mut self, board: &Board, terminal: &mut T) {
        self.console.show(board);
        self.anchor = Anchor { board_ms: board.now * 1000, wall_ms: self.clock.now_ms() };
        self.draw(terminal);
    }

    fn resize<W: Write, T: Terminal>(&mut self, size: (u16, u16), replies: &mut Replies<W>, terminal: &mut T) {
        if size == self.console.size() {
            return;
        }
        self.console.resize(size);
        replies.send(&Outbound::resize(size.0, size.1));
        if self.last_frame.is_some() {
            self.draw(terminal);
        }
    }

    fn draw<T: Terminal>(&mut self, terminal: &mut T) {
        let wall_ms = self.clock.now_ms();
        let since = i64::try_from(wall_ms.saturating_sub(self.anchor.wall_ms)).unwrap_or(i64::MAX);
        let (bytes, _) = self.console.frame(self.anchor.board_ms.saturating_add(since));
        if let Err(error) = terminal.draw(&bytes) {
            eprintln!("fun-ci-renderer: could not draw on the terminal: {error}");
        }
        self.last_frame = Some(wall_ms);
    }

    /// How long until the next frame is due; none before the first board.
    fn wait(&self) -> Option<Duration> {
        let interval = if self.console.busy() { BUSY_MS } else { IDLE_MS };
        let due = self.last_frame? + interval;
        Some(Duration::from_millis(due.saturating_sub(self.clock.now_ms())))
    }
}
