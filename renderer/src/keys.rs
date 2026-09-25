//! The bytes a raw-mode terminal sends for a keypress, as protocol key names.
//!
//! Each read is decoded on its own: terminals write an escape sequence in one
//! go, so a read that ends in a bare escape byte is the escape key.

const ESCAPE: char = '\u{1b}';

/// Every key in one read from the terminal, in order. Keys the protocol has
/// no name for (other control bytes, other escape sequences, bytes that are
/// not UTF-8) are dropped.
#[must_use]
pub fn decode(bytes: &[u8]) -> Vec<String> {
    let text = String::from_utf8_lossy(bytes);
    let mut rest = text.as_ref();
    let mut keys = Vec::new();
    let at_most_one_key_per_byte = text.len();
    for _ in 0..at_most_one_key_per_byte {
        let Some((key, length)) = next_key(rest) else { break };
        keys.extend(key);
        rest = &rest[length..];
    }
    keys
}

fn next_key(text: &str) -> Option<(Option<String>, usize)> {
    let first = text.chars().next()?;
    if first == ESCAPE {
        let (key, length) = escaped(&text[1..]);
        return Some((key, length + 1));
    }
    Some((plain(first), first.len_utf8()))
}

/// What follows an escape byte: a cursor sequence (`[` or `O`, then up to a
/// final byte), or else the escape key alone.
fn escaped(after: &str) -> (Option<String>, usize) {
    let Some(b'[' | b'O') = after.bytes().next() else { return (Some("esc".into()), 0) };
    let Some(end) = after.bytes().skip(1).position(|b| (0x40..=0x7e).contains(&b)) else {
        return (Some("esc".into()), 0);
    };
    let name = match &after[1..=end + 1] {
        "A" => Some("up".into()),
        "B" => Some("down".into()),
        _ => None,
    };
    (name, end + 2)
}

fn plain(key: char) -> Option<String> {
    match key {
        '\r' | '\n' => Some("enter".into()),
        '\u{3}' => Some("ctrl_c".into()),
        char::REPLACEMENT_CHARACTER => None,
        _ if key.is_control() => None,
        _ => Some(key.to_string()),
    }
}
