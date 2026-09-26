//! The bytes of one frame, written the way the 1.x `Screen` wrote them.

/// A frame buffer with the terminal size it draws for.
#[derive(Debug, Default)]
pub struct Screen {
    out: Vec<u8>,
    width: u16,
    height: Option<u16>,
    clears: u64,
}

impl Screen {
    #[must_use]
    pub fn new(width: u16) -> Self {
        Self { out: Vec::new(), width, height: None, clears: 0 }
    }

    #[must_use]
    pub fn width(&self) -> u16 {
        self.width
    }

    #[must_use]
    pub fn height(&self) -> Option<u16> {
        self.height
    }

    /// A new width clears the screen, so nothing drawn for the old one lingers.
    pub fn set_width(&mut self, width: u16) {
        if width != self.width {
            self.clear();
            self.width = width;
        }
    }

    /// A new height clears the screen, so nothing drawn for the old one lingers.
    pub fn set_height(&mut self, height: u16) {
        if Some(height) != self.height {
            self.clear();
            self.height = Some(height);
        }
    }

    /// `text`, then erase to the end of the line, then a raw-mode newline.
    pub fn println(&mut self, text: &str) {
        self.print(&format!("{text}\u{1b}[K\r\n"));
    }

    pub fn clear(&mut self) {
        self.print("\u{1b}[2J\u{1b}[H");
        self.clears += 1;
    }

    /// How many times the screen has been cleared.
    #[must_use]
    pub fn clears(&self) -> u64 {
        self.clears
    }

    pub fn home(&mut self) {
        self.print("\u{1b}[H");
    }

    pub fn clear_below(&mut self) {
        self.print("\u{1b}[J");
    }

    /// Moves to the 1-based `row` and `col`, then writes `text`.
    pub fn write_at(&mut self, row: usize, col: usize, text: &str) {
        self.print(&format!("\u{1b}[{row};{col}H{text}"));
    }

    pub fn save_cursor(&mut self) {
        self.print("\u{1b}[s");
    }

    pub fn restore_cursor(&mut self) {
        self.print("\u{1b}[u");
    }

    /// Everything written since the last take.
    pub fn take(&mut self) -> Vec<u8> {
        std::mem::take(&mut self.out)
    }

    fn print(&mut self, text: &str) {
        self.out.extend_from_slice(text.as_bytes());
    }
}
