//! What a terminal shows once a ratatui buffer is drawn on it, through the
//! renderer's own backend, for tests of what a widget draws.

use fun_ci_renderer::grid::{Emulator, Grid};
use fun_ci_renderer::output::backend::AnsiBackend;
use fun_ci_renderer::output::depth::Depth;
use ratatui::backend::Backend;
use ratatui::buffer::Buffer;
use ratatui::layout::Rect;

/// A blank buffer `width` by `height`.
pub fn blank(width: u16, height: u16) -> Buffer {
    Buffer::empty(Rect::new(0, 0, width, height))
}

/// The screen once `buffer` is drawn on a blank terminal its size.
pub fn shown(buffer: &Buffer) -> Grid {
    let size = (buffer.area.width, buffer.area.height);
    let mut backend = AnsiBackend::new(size, Depth::TrueColour);
    backend.draw(Buffer::empty(buffer.area).diff(buffer).into_iter()).unwrap();
    let mut emulator = Emulator::new(size);
    emulator.feed(size, &backend.take());
    emulator.grid()
}
