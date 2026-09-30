//! Where a row's parts sit (design.md, The console): the name, then the four
//! marks, the words and the age just after the longest name, so each row
//! reads as one phrase and the block is only as wide as what it holds. On a
//! narrow screen the gaps close and then the margin, before a name is cut;
//! the words never are.

/// The marks, `✓ ✓ ◆ ✓`.
const STRIP: usize = 7;
/// The space before the age, and the age itself (`now`, `40m`, `3d`).
const AGE: usize = 3 + 4;
const NAME_MAX: usize = 30;
/// Below this a name is cut so short that less air is better.
const NAME_MIN: usize = 12;
const MARGIN_MIN: usize = 2;
const GAP_WIDE: usize = 4;
const GAP_NARROW: usize = 2;

/// The columns of one screen of rows, each 0-based.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Columns {
    pub margin: usize,
    /// A project's label.
    pub label: usize,
    /// A branch's name.
    pub branch: usize,
    /// How many columns a name may take.
    pub name: usize,
    pub gap: usize,
    /// The first of the four marks.
    pub strip: usize,
    /// What happened, `failed in fast · 1.4s`.
    pub words: usize,
    /// The column the age ends before.
    pub age_end: usize,
}

impl Columns {
    /// The airiest columns on `width` that leave the longest name `longest`
    /// columns, or at least `NAME_MIN`, and the longest words whole.
    #[must_use]
    pub fn fit(width: u16, longest: usize, words: usize) -> Self {
        let width = usize::from(width);
        let want = longest.min(NAME_MAX);
        let tries = [((width / 12).max(MARGIN_MIN), GAP_WIDE), ((width / 12).max(MARGIN_MIN), GAP_NARROW), (MARGIN_MIN, GAP_NARROW)];
        let room = |(margin, gap): (usize, usize)| width.saturating_sub(2 * margin + 4 + 2 * gap + STRIP + words + AGE);
        let chosen = tries.into_iter().find(|t| room(*t) >= want.min(NAME_MIN)).unwrap_or(tries[2]);
        Self::place(chosen, want.min(room(chosen)).max(1), words)
    }

    fn place((margin, gap): (usize, usize), name: usize, words: usize) -> Self {
        let branch = margin + 4;
        let strip = branch + name + gap;
        let at = strip + STRIP + gap;
        Self { margin, label: margin + 2, branch, name, gap, strip, words: at, age_end: at + words + AGE }
    }
}
