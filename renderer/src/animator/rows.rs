//! The effects across whole rows, run by tachyonfx: a wash when a run ends,
//! its row flushing in the colour of how it ended and draining left to right;
//! and a band of light travelling along each running row, over and over,
//! while it runs. Each follows its row as the board moves (`Places`), and
//! leaves the row's four marks to the effects on them.

use ratatui::buffer::Buffer;
use ratatui::layout::Rect;
use ratatui::style::Color;
use tachyonfx::pattern::SweepPattern;
use tachyonfx::{CellFilter, Duration, Effect, EffectManager, Interpolation, RefRect, fx};

use super::draw::Places;
use super::effect::Kind;
use super::looks::{GLOW, washed};
use crate::maths::byte;
use crate::model::Run;

/// How long a wash takes to drain, and how many columns its edge is soft over.
const WASH_MS: u32 = 1_400;
const WASH_EDGE: u16 = 18;
/// How long the band of light takes to cross a running row, and how many columns it lights either side.
const GLOW_MS: u32 = 2_600;
const BAND: f32 = 7.0;
/// How far the band lifts a character towards the glow's colour at its
/// middle, in how many steps from its edges.
const LIFT: f32 = 0.55;
const LIFTS: f32 = 4.0;

/// Whose row an effect is on, and whether it is the row's wash or its glow.
type Key = (u64, bool);

/// Where one row's effect plays: its row, the marks it leaves alone, and when it ends, if it does.
#[derive(Debug)]
struct Spot {
    key: Key,
    row: RefRect,
    marks: RefRect,
    ends: Option<u64>,
}

impl Spot {
    /// Puts the spot where `places` put its row this frame, on `screen`.
    fn follow(&self, places: &Places, screen: Rect) {
        self.row.set(row(places, self.key.0).intersection(screen));
        self.marks.set(marks(places, self.key.0).intersection(screen));
    }
}

/// The rows' effects playing, where each plays, and the animation clock at the last frame.
#[derive(Debug, Default)]
pub struct Rows {
    playing: EffectManager<Key>,
    spots: Vec<Spot>,
    last_ms: Option<u64>,
}

impl Rows {
    /// Washes `run_id`'s row from `play_ms` in the colour `kind` ends a run with, if it ends one.
    pub fn wash(&mut self, kind: Kind, run_id: u64, (places, play_ms): (&Places, u64)) {
        let Some((fg, bg)) = washed(kind) else { return };
        let effect = fx::fade_from(rgb(fg), rgb(bg), (WASH_MS, Interpolation::QuadOut)).with_pattern(SweepPattern::left_to_right(WASH_EDGE));
        self.begin((run_id, true), (places, Some(play_ms + u64::from(WASH_MS))), effect);
    }

    /// Lights every running row that has no glow yet, and puts out the glow of every row that stopped.
    pub fn follow(&mut self, runs: &[Run], places: &Places) {
        let running = |id: u64| runs.iter().any(|run| run.id == id && run.status() == "running");
        let stopped: Vec<Key> = self.spots.iter().map(|spot| spot.key).filter(|(id, wash)| !wash && !running(*id)).collect();
        for key in stopped {
            self.playing.cancel_unique_effect(key);
            self.spots.retain(|spot| spot.key != key);
        }
        let unlit: Vec<u64> = runs.iter().filter(|run| run.status() == "running" && !self.glowing(run.id)).map(|run| run.id).collect();
        for id in unlit {
            self.begin((id, false), (places, None), glow());
        }
    }

    fn glowing(&self, run_id: u64) -> bool {
        self.spots.iter().any(|spot| spot.key == (run_id, false))
    }

    /// Whether a wash is playing.
    #[must_use]
    pub fn washing(&self) -> bool {
        self.spots.iter().any(|spot| spot.key.1)
    }

    /// Moves every effect on to `play_ms` and draws it into `buf` on its row.
    pub fn draw(&mut self, buf: &mut Buffer, places: &Places, play_ms: u64) {
        let since = play_ms.saturating_sub(self.last_ms.unwrap_or(play_ms));
        self.last_ms = Some(play_ms);
        self.spots.iter().for_each(|spot| spot.follow(places, buf.area));
        self.playing.process_effects(millis(since), buf, buf.area);
        self.spots.retain(|spot| spot.ends.is_none_or(|ends| ends > play_ms));
    }

    /// `effect` on `key`'s row where `places` put it, but for its marks, until
    /// `ends`, in place of any before it there.
    fn begin(&mut self, key: Key, (places, ends): (&Places, Option<u64>), effect: Effect) {
        self.spots.retain(|spot| spot.key != key);
        let spot = Spot { key, row: RefRect::new(row(places, key.0)), marks: RefRect::new(marks(places, key.0)), ends };
        let effect = effect.with_filter(CellFilter::Not(Box::new(CellFilter::RefArea(spot.marks.clone()))));
        let effect = self.playing.unique(key, fx::dynamic_area(spot.row.clone(), effect));
        self.spots.push(spot);
        self.playing.add_effect(effect);
    }
}

/// The band of light crossing a row, again and again: each character within
/// `BAND` columns of its middle lifted towards the glow's colour.
fn glow() -> Effect {
    fx::repeating(fx::effect_fn((), GLOW_MS, |(), context, cells| {
        let width = f32::from(context.area.width);
        let middle = context.alpha() * (width + 2.0 * BAND) - BAND + f32::from(context.area.x);
        for (at, cell) in cells {
            let near = 1.0 - ((f32::from(at.x) - middle).abs() / BAND).min(1.0);
            if near > 0.0 {
                cell.set_fg(lifted(cell.fg, (near * near * LIFTS).ceil() / LIFTS * LIFT));
            }
        }
    }))
}

/// `colour` moved `by` of the way towards the glow's colour.
fn lifted(colour: Color, by: f32) -> Color {
    let Color::Rgb(r, g, b) = colour else { return colour };
    let mix = |from: u8, to: u8| byte((f64::from(from) + (f64::from(to) - f64::from(from)) * f64::from(by)) / 255.0);
    Color::Rgb(mix(r, GLOW[0]), mix(g, GLOW[1]), mix(b, GLOW[2]))
}

/// `run_id`'s row, from the margin to the block's end; nothing when it is off the screen.
fn row(places: &Places, run_id: u64) -> Rect {
    across(places, run_id, places.span)
}

/// `run_id`'s four marks and the links between them; nothing when its row is off the screen.
fn marks(places: &Places, run_id: u64) -> Rect {
    across(places, run_id, (places.strip, places.strip + MARKS))
}

/// How many columns the marks and the links between them take.
const MARKS: usize = 7;

/// Columns `start` up to `end` of `run_id`'s row; nothing when it is off the screen.
fn across(places: &Places, run_id: u64, (start, end): (usize, usize)) -> Rect {
    let line = places.rows.iter().find(|(id, _)| *id == run_id).and_then(|(_, line)| u16::try_from(*line).ok());
    line.map_or_else(Rect::default, |y| Rect::new(cell(start), y, cell(end.saturating_sub(start)), 1))
}

fn cell(at: usize) -> u16 {
    u16::try_from(at).unwrap_or(u16::MAX)
}

fn millis(ms: u64) -> Duration {
    Duration::from_millis(u32::try_from(ms).unwrap_or(u32::MAX))
}

fn rgb([r, g, b]: [u8; 3]) -> Color {
    Color::Rgb(r, g, b)
}
