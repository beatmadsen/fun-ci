//! The escapes that set a cell's style: a reset, then its attributes, then
//! its colours in the depth the terminal has.

use std::fmt::Write;

use ratatui::style::{Color, Modifier};

use super::depth::{Depth, escape};

/// A cell's style: its text colour, its background and its attributes.
pub type Pen = (Color, Color, Modifier);

/// The escapes that set `pen`: a reset, then its attributes and colours.
#[must_use]
pub fn sgr((fg, bg, modifier): Pen, depth: Depth) -> String {
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

