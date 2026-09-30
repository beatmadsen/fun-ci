//! Where a row's parts sit (design.md, The console): the name, then the four
//! marks, the words and the age just after the longest name, so each row
//! reads as one phrase and the block is only as wide as what it holds. On a
//! narrow screen the gaps close and then the margin, before a name is cut;
//! the words never are. On a wide screen the gaps grow, by `GROW_MAX` at
//! most so a row still reads as one phrase, and the table is centred.

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
/// The most a wide screen widens the table by, shared between the name, the
/// gap after the marks and the gap before the age.
const GROW_MAX: usize = 24;

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
    /// The columns on `width` for names `longest` long and words `words`
    /// long: packed, then widened into the room the screen has left.
    #[must_use]
    pub fn fit(width: u16, longest: usize, words: usize) -> Self {
        Self::packed(width, longest, words).widened(width)
    }

    /// The airiest columns on `width` that leave the longest name `longest`
    /// columns, or at least `NAME_MIN`, and the longest words whole, each part
    /// just after the one before.
    #[must_use]
    pub fn packed(width: u16, longest: usize, words: usize) -> Self {
        let width = usize::from(width);
        let want = longest.min(NAME_MAX);
        let tries = [((width / 12).max(MARGIN_MIN), GAP_WIDE), ((width / 12).max(MARGIN_MIN), GAP_NARROW), (MARGIN_MIN, GAP_NARROW)];
        let room = |(margin, gap): (usize, usize)| width.saturating_sub(2 * margin + 4 + 2 * gap + STRIP + words + AGE);
        let chosen = tries.into_iter().find(|t| room(*t) >= want.min(NAME_MIN)).unwrap_or(tries[2]);
        Self::place(chosen, want.min(room(chosen)).max(1), words)
    }

    /// Whether these columns cut names `longest` long shorter than a name should be cut.
    #[must_use]
    pub fn cramped(self, longest: usize) -> bool {
        self.name < longest.min(NAME_MIN)
    }

    fn place((margin, gap): (usize, usize), name: usize, words: usize) -> Self {
        let branch = margin + 4;
        let strip = branch + name + gap;
        let at = strip + STRIP + gap;
        Self { margin, label: margin + 2, branch, name, gap, strip, words: at, age_end: at + words + AGE }
    }

    /// These columns on `width`: the room left, up to `GROW_MAX`, shared
    /// between the name, the gap after the marks and the gap before the age,
    /// and what is left after that on either side.
    fn widened(self, width: u16) -> Self {
        let spare = usize::from(width).saturating_sub(self.age_end + self.margin);
        let grow = spare.min(GROW_MAX);
        let (name, after_marks) = (grow / 3, grow / 3);
        let by = (spare - grow) / 2;
        Self {
            margin: self.margin + by,
            label: self.label + by,
            branch: self.branch + by,
            name: self.name + name,
            strip: self.strip + by + name,
            words: self.words + by + name + after_marks,
            age_end: self.age_end + by + grow,
            ..self
        }
    }
}
