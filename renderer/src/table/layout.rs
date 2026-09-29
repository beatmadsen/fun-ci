//! Where each column of the table starts, for the runs on screen and the
//! terminal's width. As the terminal narrows, the SHA goes first, then the
//! stages' times (their marks stay), then the project, which tells apart
//! same-named branches of different projects; the branch takes what is left,
//! and is cut to fit.

use crate::format::project_name;
use crate::model::Run;

/// The stages in the order their columns come, whatever order a run lists them in.
pub const STAGES: [&str; 4] = ["lint", "build", "fast", "slow"];

/// The state bar, the cursor's mark and a space.
const GUTTER: usize = 3;
const SHA: usize = 7;
const GAP: usize = 2;
/// A stage's mark, a space, and a time such as `12.3s` or `1m59`.
const CELL: usize = 7;
const OUTCOME: usize = 9;
const AGE: usize = 4;
const PROJECT_MAX: usize = 14;
/// Below this the branch is cut so short that dropping something else is better.
const BRANCH_MIN: usize = 12;
/// Past this, or a third of the width if that is more, a branch is cut
/// rather than pushing every row's stages right.
const BRANCH_MAX: usize = 32;
/// The project's width once it has to give way: its initial.
pub const PROJECT_SHORT: usize = 1;
/// Columns left empty at the right edge.
const MARGIN: usize = 1;

/// The columns of one screen of runs.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Layout {
    pub width: usize,
    pub sha: bool,
    /// The project column's width, 0 when it is left out.
    pub project: usize,
    pub times: bool,
    pub branch: usize,
    /// Whether a conflict is said in words, `conflicts main`, or as `↯ main`.
    pub words: bool,
}

impl Layout {
    /// The fullest layout of `runs` that leaves the branch room, on `width` columns.
    #[must_use]
    pub fn fit(runs: &[Run], width: u16) -> Self {
        let width = usize::from(width);
        let widest = |words: bool| runs.iter().map(|run| branch_width(run, words)).max().unwrap_or(0).min(BRANCH_MAX.max(width / 3));
        let natural = widest(false);
        let layout = |(sha, project, times)| Self { width, sha, project, times, branch: 0, words: false };
        let layouts: Vec<Self> = options(project_width(runs)).into_iter().map(layout).collect();
        let room = |layout: &Self| width.saturating_sub(layout.fixed());
        let last = layouts[layouts.len() - 1];
        let chosen = layouts.into_iter().find(|l| room(l) >= natural.min(BRANCH_MIN)).unwrap_or(last);
        let words = room(&chosen) >= widest(true);
        Self { branch: widest(words).min(room(&chosen)), words, ..chosen }
    }

    #[must_use]
    pub fn sha_column(&self) -> usize {
        GUTTER
    }

    #[must_use]
    pub fn branch_column(&self) -> usize {
        GUTTER + if self.sha { SHA + GAP } else { 0 }
    }

    #[must_use]
    pub fn project_column(&self) -> usize {
        self.branch_column() + self.branch + GAP
    }

    /// The 0-based column `stage`'s cell starts at.
    #[must_use]
    pub fn stage_column(&self, stage: &str) -> Option<usize> {
        let index = STAGES.iter().position(|s| *s == stage)?;
        Some(self.stages_column() + index * (self.cell() + GAP))
    }

    /// How many columns a stage's cell has.
    #[must_use]
    pub fn cell(&self) -> usize {
        if self.times { CELL } else { 1 }
    }

    #[must_use]
    pub fn outcome_column(&self) -> usize {
        self.stages_column() + STAGES.len() * (self.cell() + GAP)
    }

    /// The column the age ends before.
    #[must_use]
    pub fn age_end(&self) -> usize {
        self.outcome_column() + OUTCOME + 1 + AGE
    }

    fn stages_column(&self) -> usize {
        self.project_column() + if self.project > 0 { self.project + GAP } else { 0 }
    }

    /// Every column but the branch's, and the margin.
    fn fixed(&self) -> usize {
        self.age_end() - self.branch + MARGIN
    }
}

/// The layouts to try, fullest first, as (SHA, project width, times): with
/// several projects the SHA goes before the project, which tells their
/// branches apart.
fn options(project: usize) -> Vec<(bool, usize, bool)> {
    let short = project.min(PROJECT_SHORT);
    if project > 0 {
        vec![(true, project, true), (false, project, true), (false, short, true), (false, short, false), (false, 0, false)]
    } else {
        vec![(true, 0, true), (true, 0, false), (false, 0, false)]
    }
}

/// The branch's width with what follows it, a conflict in words or not.
fn branch_width(run: &Run, words: bool) -> usize {
    run.commit.branch.chars().count() + branch_tail(run, words).map_or(0, |m| m.chars().count() + 1)
}

/// What follows the branch: its conflict with the trunk, else how many runs a folded row stands for.
#[must_use]
pub fn branch_tail(run: &Run, words: bool) -> Option<String> {
    conflict_marker(run, words).or_else(|| folded_count(run))
}

/// `×25` on a row that stands for 25 cancelled runs.
#[must_use]
pub fn folded_count(run: &Run) -> Option<String> {
    run.folded.filter(|n| *n > 1).map(|n| format!("×{n}"))
}

/// `conflicts main`, or `↯ main` without `words`, when the run's branch conflicts with its trunk.
#[must_use]
pub fn conflict_marker(run: &Run, words: bool) -> Option<String> {
    let trunk = run.trunk.as_ref().filter(|t| t.branch_state == "conflicts")?;
    Some(format!("{} {}", if words { "conflicts" } else { "↯" }, trunk.trunk))
}

/// The widest project name, or 0 when every run is of the same project.
fn project_width(runs: &[Run]) -> usize {
    let names: Vec<String> = runs.iter().map(|run| run.commit.project.as_deref().map(project_name).unwrap_or_default()).collect();
    let one = names.windows(2).all(|pair| pair[0] == pair[1]);
    if one { 0 } else { names.iter().map(|n| n.chars().count()).max().unwrap_or(0).min(PROJECT_MAX) }
}
