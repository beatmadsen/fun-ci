//! The braille spinner shown in a running stage's cell: every frame at least
//! three dots, so it never looks like the single dot of a stage not reached.

const FRAMES: [char; 10] = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

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
