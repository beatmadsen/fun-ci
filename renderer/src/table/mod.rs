//! The quiet table under the header (design.md, The console): each project's
//! branches under its name, one row per branch as one phrase, what needs you
//! in one deep block that breathes, and nothing that says what happened ever
//! cut. It fits its screen by climbing down a ladder (`ladder`) and is drawn
//! cell by cell (`line`), so no line is ever wider than the terminal.

pub mod columns;
pub mod firefly;
pub mod footer;
pub mod ladder;
pub mod line;
pub mod marks;
pub mod night;
pub mod page;
pub mod paint;
pub mod rows;
pub mod sections;
pub mod stack;
pub mod words;

use crate::art::cells::byte;
use crate::art::float;
use crate::art::math::Portable;
use crate::art::output::Depth;
use crate::model::{Board, Run};
use columns::Columns;
use ladder::{Fitted, fit};
use paint::{Paint, paint};
use sections::{Section, sections};
use stack::{Piece, conflicts};

/// The stages in the order their marks come, whatever order a run lists them in.
pub const STAGES: [&str; 4] = ["lint", "build", "fast", "slow"];

/// What a frame draws with: the board's clock, the animation clock, the
/// spinner's frame, the terminal's width and colours.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Frame {
    pub now_ms: i64,
    pub play_ms: u64,
    pub spinner: char,
    pub width: u16,
    pub depth: Depth,
}

/// The table as drawn: its lines, the line each run's row is on, the
/// columns they share, and what its footer says about it.
#[derive(Debug, Clone)]
pub struct Drawn {
    pub lines: Vec<String>,
    pub rows: Vec<(u64, usize)>,
    pub columns: Columns,
    /// How many passed rows the screen was too short for.
    pub unshown: usize,
    /// Which trunks are stale, said above the footer when no label can say it.
    pub note: Option<String>,
    /// The run whose row is in the block, and the block's colour this frame.
    pub block: Option<(u64, [u8; 3])>,
}

/// A column more than the longest words, so the age stays put as a running
/// stage's seconds grow.
const WORDS_SPARE: usize = 1;
/// How long the block takes to breathe in and out.
const BREATH_MS: u64 = 4_000;
/// How many shades the block breathes through, deepest and lightest among them.
const SHADES: usize = 5;

/// The table for `board` in at most `room` lines.
#[must_use]
pub fn draw(board: &Board, frame: Frame, room: usize) -> Drawn {
    let sections = sections(&board.runs);
    let lead = lead(board);
    let (fitted, note) = fitted(board, &sections, (lead, room), frame.now_ms);
    let tags = (fitted.flat && sections.len() > 1).then(|| widest_project(&sections));
    let columns = Columns::fit(frame.width, longest_name(board) + tags.map_or(0, |tag| tag + 2), longest_words(board, frame));
    let paint_with = Paint { columns, frame, lead, stale: &board.stale_trunks, paper: paper(frame.play_ms), tags };
    let lines = fitted.pieces.iter().map(|piece| paint(piece, &paint_with)).collect();
    let block = lead.map(|run| (run, paint_with.paper));
    Drawn { lines, rows: rows(&fitted.pieces), columns, unshown: fitted.unshown, note, block }
}

/// The fitted table, and the stale trunks' note when it had to go flat, which takes a line.
fn fitted<'a>(board: &Board, sections: &'a [Section<'a>], (lead, room): (Option<u64>, usize), now_ms: i64) -> (Fitted<'a>, Option<String>) {
    let calm = !board.runs.iter().any(needs_you);
    let fitted = fit(sections, lead, room, calm);
    if !fitted.flat || board.stale_trunks.is_empty() {
        return (fitted, None);
    }
    (fit(sections, lead, room.saturating_sub(1), calm), Some(footer::stale(board, now_ms)))
}

/// The row in the block: the cursor's, else the first that needs you.
fn lead(board: &Board) -> Option<u64> {
    let cursor = board.view.cursor.and_then(|index| board.runs.get(index));
    cursor.or_else(|| board.runs.iter().find(|run| needs_you(run))).map(|run| run.id)
}

/// Whether a run needs you: it failed or timed out, or its branch conflicts with the trunk.
#[must_use]
pub fn needs_you(run: &Run) -> bool {
    matches!(run.status(), "failed" | "timeout") || conflicts(run)
}

/// The block's colour at `play_ms`: deep wine, lightening and easing once
/// every four seconds, in `SHADES` steps.
#[must_use]
pub fn paper(play_ms: u64) -> [u8; 3] {
    let turn = float(usize::try_from(play_ms % BREATH_MS).unwrap_or(0)) / float(usize::try_from(BREATH_MS).unwrap_or(1));
    let level = 0.5 - 0.5 * (turn * std::f64::consts::TAU).cosine();
    let step = (0..SHADES).map(|n| float(n) / float(SHADES - 1)).min_by(|a, b| (a - level).abs().total_cmp(&(b - level).abs())).unwrap_or(0.0);
    std::array::from_fn(|i| mix(night::WINE[i], night::WINE_BREATH[i], step))
}

fn mix(low: u8, high: u8, level: f64) -> u8 {
    let (low, high) = (f64::from(low), f64::from(high));
    byte((low + (high - low) * level) / 255.0)
}

fn rows(pieces: &[Piece]) -> Vec<(u64, usize)> {
    pieces.iter().enumerate().filter_map(|(line, piece)| if let Piece::Row(run) = piece { Some((run.id, line)) } else { None }).collect()
}

fn longest_name(board: &Board) -> usize {
    board.runs.iter().map(|run| run.commit.branch.chars().count()).max().unwrap_or(0)
}

fn longest_words(board: &Board, frame: Frame) -> usize {
    board.runs.iter().map(|run| words::said(run, frame.now_ms).chars().count()).max().unwrap_or(0) + WORDS_SPARE
}

fn widest_project(sections: &[Section]) -> usize {
    sections.iter().map(|section| section.project.chars().count()).max().unwrap_or(0)
}
