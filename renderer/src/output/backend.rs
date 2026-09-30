//! A ratatui backend that writes a frame as bytes rather than to a terminal:
//! ratatui works out which cells changed since the last frame, and this
//! writes each where it belongs, in the colours the terminal has, changing the
//! style only where it changes. The live session sends the bytes to the
//! terminal; the headless replay keeps them, so both draw the same bytes.

use std::convert::Infallible;
use std::fmt::Write;

use ratatui::backend::{Backend, ClearType, WindowSize};
use ratatui::buffer::Cell;
use ratatui::layout::{Position, Size};
use ratatui::style::{Color, Modifier};
use unicode_width::UnicodeWidthStr;

use super::depth::{Depth, escape};

/// A cell's style as the pen last wrote it.
type Pen = (Color, Color, Modifier);

/// The bytes written so far, for a terminal of `size` with `depth`'s colours.
#[derive(Debug)]
pub struct AnsiBackend {
    out: String,
    size: (u16, u16),
    depth: Depth,
    /// Where the next cell is written unless the cursor moves, and the style it would take.
    at: (Position, Option<Pen>),
}

impl AnsiBackend {
    #[must_use]
    pub fn new(size: (u16, u16), depth: Depth) -> Self {
        Self { out: String::new(), size, depth, at: (Position::ORIGIN, None) }
    }

    /// The terminal is `size` (cols, rows) from now on; ratatui redraws it all.
    pub fn resize(&mut self, size: (u16, u16)) {
        self.size = size;
    }

    pub fn set_depth(&mut self, depth: Depth) {
        self.depth = depth;
    }

    /// The bytes written since the last take.
    pub fn take(&mut self) -> Vec<u8> {
        std::mem::take(&mut self.out).into_bytes()
    }

    fn move_to(&mut self, to: Position) {
        if self.at.0 != to {
            let _ = write!(self.out, "\u{1b}[{};{}H", to.y + 1, to.x + 1);
            self.at.0 = to;
        }
    }

    fn write_cell(&mut self, x: u16, y: u16, cell: &Cell) {
        self.move_to(Position { x, y });
        let pen = (cell.fg, cell.bg, cell.modifier);
        if self.at.1 != Some(pen) {
            self.out.push_str(&sgr(pen, self.depth));
            self.at.1 = Some(pen);
        }
        self.out.push_str(cell.symbol());
        let wide = u16::try_from(cell.symbol().width().max(1)).unwrap_or(1);
        self.at.0.x = x.saturating_add(wide);
    }
}

/// The escapes that set `pen`: a reset, then its attributes and colours.
fn sgr((fg, bg, modifier): Pen, depth: Depth) -> String {
    let attributes = [(Modifier::BOLD, "1"), (Modifier::DIM, "2"), (Modifier::ITALIC, "3"), (Modifier::UNDERLINED, "4"), (Modifier::REVERSED, "7")];
    let mut out = "\u{1b}[0m".to_string();
    for (_, code) in attributes.iter().filter(|(attribute, _)| modifier.contains(*attribute)) {
        let _ = write!(out, "\u{1b}[{code}m");
    }
    out + &colour(38, fg, depth) + &colour(48, bg, depth)
}

/// The escape setting `layer` (38 text, 48 background) to `color`; none for the terminal's default.
fn colour(layer: u8, color: Color, depth: Depth) -> String {
    match (color, named(color)) {
        (Color::Rgb(r, g, b), _) => escape(layer, [r, g, b], depth),
        (Color::Indexed(n), _) => format!("\u{1b}[{layer};5;{n}m"),
        (_, Some(n)) if n < 8 => format!("\u{1b}[{}m", u16::from(layer - 8) + u16::from(n)),
        (_, Some(n)) => format!("\u{1b}[{}m", u16::from(layer - 8) + 60 + u16::from(n - 8)),
        _ => String::new(),
    }
}

/// The terminal's own number for a named colour, 0 to 15.
fn named(color: Color) -> Option<u8> {
    const NAMES: [Color; 16] = [
        Color::Black, Color::Red, Color::Green, Color::Yellow, Color::Blue, Color::Magenta, Color::Cyan, Color::Gray,
        Color::DarkGray, Color::LightRed, Color::LightGreen, Color::LightYellow, Color::LightBlue, Color::LightMagenta,
        Color::LightCyan, Color::White,
    ];
    NAMES.iter().position(|name| *name == color).and_then(|n| u8::try_from(n).ok())
}

impl Backend for AnsiBackend {
    type Error = Infallible;

    fn draw<'a, I>(&mut self, content: I) -> Result<(), Self::Error>
    where
        I: Iterator<Item = (u16, u16, &'a Cell)>,
    {
        for (x, y, cell) in content {
            self.write_cell(x, y, cell);
        }
        if self.at.1.take().is_some() {
            self.out.push_str("\u{1b}[0m");
        }
        Ok(())
    }

    fn hide_cursor(&mut self) -> Result<(), Self::Error> {
        self.out.push_str("\u{1b}[?25l");
        Ok(())
    }

    fn show_cursor(&mut self) -> Result<(), Self::Error> {
        self.out.push_str("\u{1b}[?25h");
        Ok(())
    }

    fn get_cursor_position(&mut self) -> Result<Position, Self::Error> {
        Ok(self.at.0)
    }

    fn set_cursor_position<P: Into<Position>>(&mut self, position: P) -> Result<(), Self::Error> {
        self.move_to(position.into());
        Ok(())
    }

    fn clear(&mut self) -> Result<(), Self::Error> {
        self.clear_region(ClearType::All)
    }

    fn clear_region(&mut self, clear_type: ClearType) -> Result<(), Self::Error> {
        self.out.push_str(match clear_type {
            ClearType::All => "\u{1b}[2J\u{1b}[H",
            ClearType::AfterCursor => "\u{1b}[J",
            ClearType::BeforeCursor => "\u{1b}[1J",
            ClearType::CurrentLine => "\u{1b}[2K",
            ClearType::UntilNewLine => "\u{1b}[K",
        });
        if clear_type == ClearType::All {
            self.at = (Position::ORIGIN, None);
        }
        Ok(())
    }

    fn size(&self) -> Result<Size, Self::Error> {
        Ok(Size { width: self.size.0, height: self.size.1 })
    }

    fn window_size(&mut self) -> Result<WindowSize, Self::Error> {
        Ok(WindowSize { columns_rows: self.size()?, pixels: Size::default() })
    }

    fn flush(&mut self) -> Result<(), Self::Error> {
        Ok(())
    }
}
