//! Where effects land on the screen, as the board's layout says (`Places`):
//! a stage's effect on its mark, on its run's row (`marks`), and an effect's
//! banner on the line under the table. Effects know nothing of how the table
//! is drawn, only where.

use ratatui::buffer::Buffer;
use ratatui::layout::Rect;

use super::effect::Effect;
use super::footer::banner;
use crate::format::columns;
use crate::model::Run;

/// Where things are on the screen this frame, from 0: each run's row, the
/// column of the first of its marks, which come two apart, and the line
/// under the table, if there is a table.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Places {
    pub rows: Vec<(u64, usize)>,
    pub strip: usize,
    pub banner: Option<usize>,
}

/// The banner of the most important effect that has one, centred on the line under the table.
pub fn footer(buf: &mut Buffer, effects: &[Effect], (runs, places): (&[Run], &Places), play_ms: u64) {
    let shown = most_important(effects).and_then(|effect| banner(effect, runs, play_ms));
    let (Some((text, style)), Some(y)) = (shown, places.banner.and_then(|y| u16::try_from(y).ok())) else { return };
    let line = Rect::new(buf.area.x, y, buf.area.width, 1).intersection(buf.area);
    line.positions().for_each(|at| buf[at].reset());
    let pad = usize::from(line.width).saturating_sub(columns(&text)) / 2;
    buf.set_stringn(line.x + u16::try_from(pad).unwrap_or(0), line.y, text, usize::from(line.width), style);
}

fn most_important(effects: &[Effect]) -> Option<&Effect> {
    let candidates = effects.iter().filter(|e| e.kind.has_footer());
    candidates.fold(None, |best: Option<&Effect>, e| match best {
        Some(b) if b.kind.priority() >= e.kind.priority() => Some(b),
        _ => Some(e),
    })
}
