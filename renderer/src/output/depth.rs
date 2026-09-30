//! How many colours the terminal shows, and the escape that sets a colour in
//! that many: 24-bit where the terminal has it, else the nearest of xterm's 256.

/// How many colours the terminal shows.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Depth {
    TrueColour,
    Xterm256,
}

const CUBE: [u8; 6] = [0, 95, 135, 175, 215, 255];

/// The SGR escape setting `layer` (38 text, 48 background) to `rgb`, in `depth`.
#[must_use]
pub fn escape(layer: u8, rgb: [u8; 3], depth: Depth) -> String {
    match depth {
        Depth::TrueColour => format!("\u{1b}[{layer};2;{};{};{}m", rgb[0], rgb[1], rgb[2]),
        Depth::Xterm256 => format!("\u{1b}[{layer};5;{}m", xterm(rgb)),
    }
}

/// The xterm colour (16-255) nearest `rgb`.
#[must_use]
pub fn xterm(rgb: [u8; 3]) -> u8 {
    let levels = rgb.map(nearest_level);
    let cube = levels.map(|level| CUBE[usize::from(level)]);
    let grey_step = ((u16::from(rgb[0]) + u16::from(rgb[1]) + u16::from(rgb[2])) / 3).saturating_sub(3) / 10;
    let grey_step = u8::try_from(grey_step.min(23)).unwrap_or(23);
    let grey = [8 + 10 * grey_step; 3];
    if distance(rgb, grey) < distance(rgb, cube) { 232 + grey_step } else { 16 + 36 * levels[0] + 6 * levels[1] + levels[2] }
}

fn nearest_level(channel: u8) -> u8 {
    let gap = |level: &u8| channel.abs_diff(*level);
    let index = CUBE.iter().enumerate().min_by_key(|(_, level)| gap(level)).map_or(0, |(i, _)| i);
    u8::try_from(index).unwrap_or(0)
}

fn distance(a: [u8; 3], b: [u8; 3]) -> u32 {
    (0..3).map(|i| u32::from(a[i].abs_diff(b[i])).pow(2)).sum()
}
