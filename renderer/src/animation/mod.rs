//! Animations as data (`renderer/animations/*.json`).

mod file;
mod library;
mod style;

use serde::Deserialize;

pub use library::Library;
pub use style::Style;

/// How an animation plays: frame duration, whether it loops, where it sits.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub struct Playback {
    pub frame_ms: u32,
    #[serde(rename = "loop")]
    pub looped: bool,
    pub anchor: String,
}

/// One line of an animation frame, ready to write to a terminal.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StyledLine {
    ansi: String,
    width: usize,
}

impl StyledLine {
    #[must_use]
    pub fn new(ansi: String, width: usize) -> Self {
        Self { ansi, width }
    }

    /// The line with its SGR escapes; it starts and ends in the default style.
    #[must_use]
    pub fn ansi(&self) -> &str {
        &self.ansi
    }

    /// Columns the line covers.
    #[must_use]
    pub fn width(&self) -> usize {
        self.width
    }
}

/// The lines of one frame, top to bottom.
pub type Frame = Vec<StyledLine>;

/// A named sequence of frames.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Animation {
    name: String,
    playback: Playback,
    frames: Vec<Frame>,
}

impl Animation {
    /// Reads one animation file.
    ///
    /// # Errors
    /// When the JSON is malformed, or a style mask does not fit its text.
    pub fn from_json(json: &str) -> Result<Self, String> {
        let parsed: file::AnimationFile = serde_json::from_str(json).map_err(|e| e.to_string())?;
        let frames = parsed.art.frames()?;
        Ok(Self { name: parsed.name, playback: parsed.playback, frames })
    }

    /// An animation with no frames, for a name the library lacks.
    #[must_use]
    pub fn blank(name: &str) -> Self {
        let playback = Playback { frame_ms: 100, looped: true, anchor: "header".to_string() };
        Self { name: name.to_string(), playback, frames: Vec::new() }
    }

    #[must_use]
    pub fn name(&self) -> &str {
        &self.name
    }

    #[must_use]
    pub fn playback(&self) -> &Playback {
        &self.playback
    }

    #[must_use]
    pub fn frames(&self) -> &[Frame] {
        &self.frames
    }
}
