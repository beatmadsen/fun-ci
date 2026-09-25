use serde::Deserialize;

/// The SGR attributes one character of an animation is drawn in.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Deserialize)]
pub struct Style {
    pub fg: Option<u8>,
    #[serde(default)]
    pub bold: bool,
    #[serde(default)]
    pub dim: bool,
}

impl Style {
    /// The escape that sets exactly this style, from a reset.
    #[must_use]
    pub fn sgr(&self) -> String {
        let mut params = vec!["0".to_string()];
        params.extend(self.bold.then(|| "1".to_string()));
        params.extend(self.dim.then(|| "2".to_string()));
        params.extend(self.fg.map(colour));
        format!("\u{1b}[{}m", params.join(";"))
    }
}

fn colour(index: u8) -> String {
    match index {
        0..=7 => format!("{}", 30 + index),
        8..=15 => format!("{}", 82 + index),
        _ => format!("38;5;{index}"),
    }
}
