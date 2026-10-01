//! The quiet table under the header (design.md, The console): each project's
//! branches under its name, one row per branch as one phrase, what needs you
//! in one deep block that breathes, and nothing that says what happened ever
//! cut. It fits its screen by climbing down a ladder (`ladder`) and is drawn
//! cell by cell (`line`), so no line is ever wider than the terminal.

pub mod columns;
pub mod firefly;
pub mod footer;
pub mod job_rows;
pub mod job_words;
pub mod jobs;
pub mod ladder;
pub mod leaders;
pub mod legend;
pub mod line;
pub mod marks;
pub mod night;
pub mod page;
pub mod paint;
pub mod rows;
pub mod sections;
pub mod sheet;
pub mod sky;
pub mod stack;
pub mod words;

use crate::maths::{Portable, float};
use crate::format::columns;
use crate::model::{Board, Run};
use columns::Columns;
use ladder::{Fitted, fit};
use paint::{Paint, paint};
use sections::{Section, sections};
use sheet::Paper;
use stack::{Piece, conflicts};

pub use crate::model::STAGES;

/// What a frame draws with: the board's clock, the animation clock, the
/// spinner's frame and the terminal's width.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Frame {
    pub now_ms: i64,
    pub play_ms: u64,
    pub spinner: char,
    pub width: u16,
}

/// The table as drawn: its lines, the line each run's row is on, the
/// columns they share, and what its footer says about it.
#[derive(Debug, Clone)]
pub struct Drawn {
    pub lines: Vec<ratatui::text::Line<'static>>,
    pub rows: Vec<(u64, usize)>,
    pub columns: Columns,
    /// How many passed rows the screen was too short for.
    pub unshown: usize,
    /// Which trunks are stale, said above the footer when no label can say it.
    pub note: Option<String>,
    /// The lead's block this frame, where its row is on the screen.
    pub paper: Option<Paper>,
    /// The lines down from the legend to the first row's marks.
    pub leaders: Option<leaders::Leaders>,
}

/// A column more than the longest words, so the age stays put as a running
/// stage's seconds grow.
const WORDS_SPARE: usize = 1;
/// How long the block takes to breathe in and out.
const BREATH_MS: u64 = 4_000;
/// How many shades the block breathes through, deepest and lightest among them.
const SHADES: usize = 5;

/// The table for `board` in at most `room` lines, the daily and weekly jobs under it.
#[must_use]
pub fn draw(board: &Board, frame: Frame, room: usize) -> Drawn {
    let sections = sections(&board.runs);
    let (lead, job_lead) = (lead(board), jobs::lead(board));
    let named = jobs::many_projects(board);
    let (fitted, note, section) = with_jobs((board, frame), &sections, (lead, room), jobs::shapes(board, job_lead, named));
    let pieces: Vec<Piece> = fitted.pieces.iter().cloned().chain(section).collect();
    let tags = (fitted.flat && sections.len() > 1).then(|| widest_project(&sections));
    let (columns, brief) = laid_out(board, frame, longest_name(board, named) + tags.map_or(0, |tag| tag + 2));
    let note = above_footer(board, columns, frame).or(note);
    let paint_with = Paint { columns, frame, lead, stale: &board.stale_trunks, tags, brief };
    let lines = pieces.iter().map(|piece| paint(piece, &paint_with)).collect();
    let paper = Paper::over(&pieces, lead, columns, paper(frame.play_ms, lead_needs_you(board, lead, job_lead)));
    let leaders = leaders::Leaders::over(&pieces, columns.strip);
    Drawn { lines, rows: rows(&pieces), columns, unshown: fitted.unshown, note, paper, leaders }
}

/// The table fitted with the most of the job section it has room for while
/// it keeps all its own lines: the section gives up its lines before any
/// branch does. When even its last shape leaves the table too little, the
/// table climbs down its own ladder; and when that leaves a branch off the
/// screen that the whole screen would show, the section goes, since the jobs
/// come after the branches. Rows the cursor is on (the section's only shape
/// then) stay.
fn with_jobs<'a>((board, frame): (&Board, Frame), sections: &'a [Section<'a>], (lead, room): (Option<u64>, usize), shapes: Vec<Vec<Piece<'a>>>) -> (Fitted<'a>, Option<String>, Vec<Piece<'a>>) {
    let whole = fitted(board, sections, (lead, usize::MAX), frame).0.pieces;
    let apart = |shape: &[Piece]| usize::from(!shape.is_empty() && whole.last() != Some(&Piece::Blank));
    let (last, yields) = (shapes.len() - 1, shapes.len() > 1);
    let chosen = shapes.iter().position(|shape| whole.len() + apart(shape) + shape.len() <= room).unwrap_or(last);
    let section = shapes.into_iter().nth(chosen).unwrap_or_default();
    let reserved = apart(&section);
    let (table, note) = fitted(board, sections, (lead, room.saturating_sub(section.len() + reserved)), frame);
    let alone = fitted(board, sections, (lead, room), frame);
    if yields && hidden(&table) > hidden(&alone.0) {
        return (alone.0, alone.1, Vec::new());
    }
    let blank = reserved == 1 && table.pieces.last() != Some(&Piece::Blank);
    (table, note, blank.then_some(Piece::Blank).into_iter().chain(section).collect())
}

/// How many branch rows the fitted table leaves off the screen: the passed
/// rows it left out, and those it paged off.
fn hidden(table: &Fitted) -> usize {
    table.unshown + table.pieces.iter().map(|piece| if let Piece::More(rows, _) = piece { *rows } else { 0 }).sum::<usize>()
}

/// The command for the failed job under the cursor, when it is too long to
/// go whole beside the footer's keys: it takes the line above the footer.
fn above_footer(board: &Board, columns: Columns, frame: Frame) -> Option<String> {
    let width = usize::from(frame.width);
    footer::why_job(board).filter(|_| footer::why_job_beside(board, columns, width).is_none())
}

/// Whether the row in the block needs you, which makes the block wine.
fn lead_needs_you(board: &Board, lead: Option<u64>, job_lead: Option<usize>) -> bool {
    let run = board.runs.iter().any(|run| lead == Some(run.id) && needs_you(run));
    run || job_lead.and_then(|index| board.jobs.get(index)).is_some_and(jobs::needs_you)
}

/// The fitted table, and the line it says above the footer: the stale
/// trunks when it had to go flat, which takes a line, or else the one-line
/// legend when it had no room for the full one.
fn fitted<'a>(board: &Board, sections: &'a [Section<'a>], (lead, room): (Option<u64>, usize), frame: Frame) -> (Fitted<'a>, Option<String>) {
    let calm = !board.runs.iter().any(needs_you);
    let fitted = fit(sections, lead, room, calm);
    if !fitted.flat || board.stale_trunks.is_empty() {
        let rows = fitted.pieces.iter().any(|piece| matches!(piece, Piece::Row(_)));
        let key = (rows && !fitted.legend).then(|| legend::key(frame.width, NOTE_AT).to_string());
        return (fitted, key);
    }
    (fit(sections, lead, room.saturating_sub(1), calm), Some(footer::stale(board, frame.now_ms)))
}

/// About where a note above the footer starts: the labels' column on a narrow screen.
const NOTE_AT: usize = 4;

/// The row in the block: the cursor's, else the first that needs you; none
/// while the cursor is on a job.
fn lead(board: &Board) -> Option<u64> {
    if jobs::lead(board).is_some() {
        return None;
    }
    let cursor = board.view.cursor.and_then(|index| board.runs.get(index));
    cursor.or_else(|| board.runs.iter().find(|run| needs_you(run))).map(|run| run.id)
}

/// Whether a run needs you: it failed or timed out, or its branch conflicts with the trunk.
#[must_use]
pub fn needs_you(run: &Run) -> bool {
    matches!(run.status(), "failed" | "timeout") || conflicts(run)
}

/// The block's colour at `play_ms`: deep wine when its row needs you, else
/// deep indigo, lightening and easing once every four seconds, in `SHADES` steps.
#[must_use]
pub fn paper(play_ms: u64, needs: bool) -> [u8; 3] {
    let turn = float(usize::try_from(play_ms % BREATH_MS).unwrap_or(0)) / float(usize::try_from(BREATH_MS).unwrap_or(1));
    let level = 0.5 - 0.5 * (turn * std::f64::consts::TAU).cosine();
    let step = (0..SHADES).map(|n| float(n) / float(SHADES - 1)).min_by(|a, b| (a - level).abs().total_cmp(&(b - level).abs())).unwrap_or(0.0);
    let (deep, light) = if needs { (night::WINE, night::WINE_BREATH) } else { (night::INDIGO, night::INDIGO_BREATH) };
    night::blend(deep, light, step)
}

fn rows(pieces: &[Piece]) -> Vec<(u64, usize)> {
    pieces.iter().enumerate().filter_map(|(line, piece)| if let Piece::Row(run) = piece { Some((run.id, line)) } else { None }).collect()
}

fn longest_name(board: &Board, named: bool) -> usize {
    let jobs = board.jobs.iter().map(|job| columns(&jobs::name(job, named)));
    board.runs.iter().map(|run| columns(&run.commit.branch)).chain(jobs).max().unwrap_or(0)
}

/// The columns for names `names` wide, and whether the words must be brief
/// to leave the names their room.
fn laid_out(board: &Board, frame: Frame, names: usize) -> (Columns, bool) {
    let full = Columns::fit(frame.width, names, longest_words(board, frame, false));
    if !full.cramped(names) {
        return (full, false);
    }
    (Columns::fit(frame.width, names, longest_words(board, frame, true)), true)
}

fn longest_words(board: &Board, frame: Frame, brief: bool) -> usize {
    let said = |job| if brief { job_words::said_briefly(job, frame.now_ms) } else { job_words::said(job, frame.now_ms) };
    let jobs = board.jobs.iter().map(|job| columns(&said(job)));
    board.runs.iter().map(|run| columns(&words::phrase(run, frame.now_ms, brief))).chain(jobs).max().unwrap_or(0) + WORDS_SPARE
}

fn widest_project(sections: &[Section]) -> usize {
    sections.iter().map(|section| columns(&section.project)).max().unwrap_or(0)
}
