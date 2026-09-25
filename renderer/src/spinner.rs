//! The braille spinner shown beside a running stage.

const FRAMES: [char; 8] = ['\u{2800}', '\u{2801}', '\u{2803}', '\u{2807}', '\u{280F}', '\u{281F}', '\u{283F}', '\u{287F}'];

/// Cycles through the braille frames, one step per drawn frame.
#[derive(Debug, Default)]
pub struct Spinner {
    index: usize,
}

impl Spinner {
    #[must_use]
    pub fn current(&self) -> char {
        FRAMES[self.index]
    }

    pub fn advance(&mut self) {
        self.index = (self.index + 1) % FRAMES.len();
    }
}
