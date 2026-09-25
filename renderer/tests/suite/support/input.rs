//! Input a session reads to its end exactly once.

use std::io::{self, BufRead, Read};

/// `text`, then end of input; reading on after that end fails the test. A
/// session that never stops (a mutant of `Live::handle` once made one) would
/// otherwise read end of input forever and hang the test until
/// cargo-mutants' timeout.
pub struct EndsOnce {
    text: Vec<u8>,
    at: usize,
    ended: bool,
}

#[must_use]
pub fn ends_once(text: &str) -> EndsOnce {
    EndsOnce { text: text.as_bytes().to_vec(), at: 0, ended: false }
}

impl Read for EndsOnce {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        let taken = self.fill_buf()?.read(buffer)?;
        self.consume(taken);
        Ok(taken)
    }
}

impl BufRead for EndsOnce {
    fn fill_buf(&mut self) -> io::Result<&[u8]> {
        if self.at == self.text.len() {
            assert!(!self.ended, "the session read on past the end of its input");
            self.ended = true;
        }
        Ok(&self.text[self.at..])
    }

    fn consume(&mut self, amount: usize) {
        self.at += amount;
    }
}
