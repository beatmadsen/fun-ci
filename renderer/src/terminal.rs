//! The terminal the live renderer owns. A trait, so the protocol logic can be
//! tested without one.

use std::io;

/// What the session needs from a terminal.
pub trait Terminal {
    /// Columns and rows.
    fn size(&self) -> (u16, u16);

    /// Enters raw mode and the alternate screen.
    ///
    /// # Errors
    /// When the terminal refuses the mode change.
    fn enter(&mut self) -> io::Result<()>;

    /// Leaves the alternate screen and raw mode. Safe to call more than once.
    ///
    /// # Errors
    /// When the terminal refuses the mode change.
    fn restore(&mut self) -> io::Result<()>;

    /// Writes one frame's bytes.
    ///
    /// # Errors
    /// When the terminal cannot be written to.
    fn draw(&mut self, bytes: &[u8]) -> io::Result<()>;
}
