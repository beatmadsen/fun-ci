//! What the table is made of, top to bottom, before it is drawn. How much air
//! and how many passed rows it keeps is a `Rung` of the ladder `fit` climbs
//! down until the table fits its screen.

use super::sections::Section;
use crate::model::{Job, Run};

/// One line of the table, before it is drawn.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Piece<'a> {
    Blank,
    Label(&'a Section<'a>),
    Row(&'a Run),
    /// The line under a row that says its branch conflicts with the trunk.
    Conflict(&'a Run),
    /// The block's top edge (`true`) or bottom edge.
    Edge(bool),
    /// A project's passed branches on one line.
    Folded(Vec<&'a Run>),
    /// How many rows are off the screen, below it (`true`) or above.
    More(usize, bool),
    /// Line `n` of the legend that names each stage over its mark.
    Legend(usize),
    /// The label over the daily and weekly jobs, `daily & weekly`, `daily` or `weekly`.
    JobsLabel(&'static str),
    /// A job's row: the job, its name as shown, and whether it leads.
    Job(&'a Job, String, bool),
    /// The jobs on one pale line, when none needs you or runs.
    JobsFolded(&'a [Job]),
    /// The jobs counted on one line, on a short screen, under their label's words.
    JobsCounted(&'a [Job], &'static str),
}

/// Which passed rows fold into one line per project: none, a project's
/// when it has two or more, or all.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Fold {
    Never,
    Many,
    All,
}

/// How much the table keeps: a blank line after each row, the projects'
/// labels, which passed rows fold, and the folded lines themselves.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Rung {
    pub gap: bool,
    pub labels: bool,
    pub fold: Fold,
    pub passed: bool,
}

/// How many lines the legend takes: one a stage.
pub const LEGEND_LINES: usize = 4;

/// The pieces of `sections` on `rung`, the row `lead` in the block. A
/// section the rung leaves nothing of, its passed rows left out, takes no
/// line: a label with nothing under it would head nothing.
#[must_use]
pub fn stack<'a>(sections: &'a [Section<'a>], lead: Option<u64>, rung: Rung) -> Vec<Piece<'a>> {
    let labelled = rung.labels && sections.len() > 1;
    let mut out = Vec::new();
    for section in sections.iter().filter(|section| shows(section, lead, rung)) {
        if rung.labels {
            out.push(Piece::Blank);
        }
        if labelled {
            out.push(Piece::Label(section));
            gap(&mut out, rung);
        }
        rows(&mut out, section, lead, rung);
    }
    out
}

/// `pieces` under the legend, which belongs to no project: a blank line,
/// then the legend's lines, above everything else; unchanged when there is
/// no row for the legend to explain.
#[must_use]
pub fn with_legend(pieces: Vec<Piece<'_>>) -> Vec<Piece<'_>> {
    if !pieces.iter().any(|piece| matches!(piece, Piece::Row(_))) {
        return pieces;
    }
    std::iter::once(Piece::Blank).chain((0..LEGEND_LINES).map(Piece::Legend)).chain(pieces).collect()
}

/// Whether `rung` shows anything of `section`: a row, or its folded line.
fn shows(section: &Section, lead: Option<u64>, rung: Rung) -> bool {
    rung.passed || folded(section, lead, rung.fold).len() < section.runs.len()
}

fn rows<'a>(out: &mut Vec<Piece<'a>>, section: &'a Section<'a>, lead: Option<u64>, rung: Rung) {
    let folded = folded(section, lead, rung.fold);
    for run in section.runs.iter().copied().filter(|run| !folded.contains(run)) {
        row(out, run, lead == Some(run.id), rung);
    }
    if !folded.is_empty() && rung.passed {
        out.push(Piece::Folded(folded));
        gap(out, rung);
    }
}

/// A row and its conflict, in the block when it leads.
fn row<'a>(out: &mut Vec<Piece<'a>>, run: &'a Run, leads: bool, rung: Rung) {
    if leads && rung.gap && out.last() == Some(&Piece::Blank) {
        out.pop();
    }
    out.extend(leads.then_some(Piece::Edge(true)));
    out.push(Piece::Row(run));
    out.extend(conflicts(run).then_some(Piece::Conflict(run)));
    if leads {
        out.push(Piece::Edge(false));
    } else {
        gap(out, rung);
    }
}

fn gap(out: &mut Vec<Piece>, rung: Rung) {
    if rung.gap {
        out.push(Piece::Blank);
    }
}

/// The section's passed rows that fold: not the lead's, not one that conflicts.
fn folded<'a>(section: &Section<'a>, lead: Option<u64>, fold: Fold) -> Vec<&'a Run> {
    let quiet = |run: &&&Run| run.status() == "passed" && !conflicts(run) && lead != Some(run.id);
    let passed: Vec<&Run> = section.runs.iter().filter(quiet).copied().collect();
    match fold {
        Fold::All => passed,
        Fold::Many if passed.len() > 1 => passed,
        _ => Vec::new(),
    }
}

/// Whether the run's branch conflicts with its trunk.
#[must_use]
pub fn conflicts(run: &Run) -> bool {
    run.trunk.as_ref().is_some_and(|trunk| trunk.branch_state == "conflicts")
}
