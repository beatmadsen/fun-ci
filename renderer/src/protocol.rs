//! Protocol v1 messages (`docs/renderer-protocol.md`).

use serde::Deserialize;
use serde_json::{Value, json};

use crate::model::{Board, Event};

const KNOWN_TYPES: [&str; 6] = ["hello", "board", "event", "resize", "tick", "quit"];

/// A message from Ruby (or, headless, from a scenario file).
#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(tag = "t", rename_all = "snake_case")]
pub enum Inbound {
    Hello { v: Option<u64> },
    Board(Box<Board>),
    Event(Event),
    Resize { cols: u16, rows: u16 },
    Tick { ms: u64 },
    Quit,
}

/// Why a line could not be understood, as the `error` message's `code`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ParseError {
    Parse(String),
    UnknownType(String),
}

impl ParseError {
    fn parse(error: &impl ToString) -> Self {
        Self::Parse(error.to_string())
    }

    /// The `error` line that answers this failure.
    #[must_use]
    pub fn reply(&self) -> Outbound {
        match self {
            Self::Parse(detail) => Outbound::error("parse", detail),
            Self::UnknownType(detail) => Outbound::error("unknown_type", detail),
        }
    }
}

/// Parses one JSON line.
///
/// # Errors
/// `Parse` for anything that is not a well-formed message object,
/// `UnknownType` for a `t` this version does not know.
pub fn parse(line: &str) -> Result<Inbound, ParseError> {
    let value: Value = serde_json::from_str(line).map_err(|e| ParseError::parse(&e))?;
    let kind = value.get("t").and_then(Value::as_str).ok_or_else(|| ParseError::parse(&"no type"))?;
    if !KNOWN_TYPES.contains(&kind) {
        return Err(ParseError::UnknownType(kind.to_string()));
    }
    serde_json::from_value(value).map_err(|e| ParseError::parse(&e))
}

/// A message to Ruby.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Outbound(String);

impl Outbound {
    #[must_use]
    pub fn ready(cols: u16, rows: u16) -> Self {
        Self::from(&json!({"t": "ready", "v": crate::PROTOCOL_VERSION, "cols": cols, "rows": rows}))
    }

    #[must_use]
    pub fn key(key: &str) -> Self {
        Self::from(&json!({"t": "key", "key": key}))
    }

    #[must_use]
    pub fn resize(cols: u16, rows: u16) -> Self {
        Self::from(&json!({"t": "resize", "cols": cols, "rows": rows}))
    }

    #[must_use]
    pub fn error(code: &str, detail: &str) -> Self {
        Self::from(&json!({"t": "error", "code": code, "detail": detail}))
    }

    /// The line, without its newline.
    #[must_use]
    pub fn line(&self) -> &str {
        &self.0
    }

    fn from(value: &Value) -> Self {
        Self(value.to_string())
    }
}
