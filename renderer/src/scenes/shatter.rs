//! Failure: the glass breaks. At the impact the header jolts and shakes,
//! cracks race out jagged from the point with a ring round it, the pane
//! flushes red, and shards break off and fall.

use crate::art::math::Portable;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, streak};
use crate::art::noise::dice;
use crate::art::{Shade, add, float, mix, scale, seconds, smoothstep};

const LENGTH_MS: u64 = 3400;
const IMPACT_AT: f64 = 0.15;
const CRACKS: u64 = 12;
const SHARDS: u64 = 22;
const PANE: Shade = [0.03, 0.035, 0.05];
const CRACK: Shade = [1.3, 1.2, 1.2];
const ALARM: Shade = [0.5, 0.03, 0.02];

#[derive(Debug)]
pub struct Shatter;

impl Scene for Shatter {
    fn name(&self) -> &'static str {
        "shatter"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let (width, height) = canvas.size();
        let hit = (width * 0.46 + shake(t, 1), height * 0.45 + shake(t, 2) * 0.5);
        let (flush, fade) = (alarm(t), 1.0 - smoothstep(2.9, 3.4, t));
        canvas.map(|_, y, _| add(mix(PANE, [0.05, 0.05, 0.07], y / height), scale(ALARM, flush)));
        (0..CRACKS).for_each(|i| crack(canvas, hit, i, (grown(t), fade)));
        ring(canvas, hit, grown(t) * fade);
        (0..SHARDS).for_each(|i| shard(canvas, hit, i, t - 1.1));
        glow(canvas, hit, 7.0, scale([1.2, 0.9, 0.9], (-(t - IMPACT_AT).abs() / 0.08).exponential()));
    }
}

/// The jolt at `t` along one axis: a hard shake after the impact, dying fast.
fn shake(t: f64, axis: u64) -> f64 {
    let since = (t - IMPACT_AT).max(0.0);
    6.0 * (-since * 4.0).exponential() * (since * 55.0 + float(usize::try_from(axis).unwrap_or(0))).sine()
}

/// How red the pane flushes at `t`: a pulse at the impact, then two slow throbs.
fn alarm(t: f64) -> f64 {
    let pulse = 0.5 + 0.5 * (t * 4.2).cosine();
    smoothstep(IMPACT_AT, IMPACT_AT + 0.1, t) * (0.25 + 0.35 * pulse) * (1.0 - smoothstep(2.6, 3.4, t))
}

/// How far the cracks have run by `t`, from 0 at the impact to 1.
fn grown(t: f64) -> f64 {
    smoothstep(IMPACT_AT, IMPACT_AT + 0.45, t)
}

/// Crack `i` from `hit`: a jagged line out at its angle, `grown` of its length.
fn crack(canvas: &mut Canvas, hit: (f64, f64), i: u64, (grown, fade): (f64, f64)) {
    let angle = (float(usize::try_from(i).unwrap_or(0)) + dice(i, 131) * 0.6) / float(12) * std::f64::consts::TAU;
    let length = (60.0 + 90.0 * dice(i, 132)) * grown;
    let mut from = hit;
    for step in 1..=8_u64 {
        let reach = length * float(usize::try_from(step).unwrap_or(0)) / 8.0;
        let jag = (dice(i * 16 + step, 133) - 0.5) * 7.0;
        let to = (hit.0 + angle.cosine() * reach - angle.sine() * jag, hit.1 + f64::midpoint(angle.sine() * reach, angle.cosine() * jag));
        streak(canvas, (from, to), 0.75, scale(CRACK, fade * (1.0 - 0.07 * float(usize::try_from(step).unwrap_or(0)))));
        from = to;
    }
}

/// The ring crack round the impact, drawn as short chords.
fn ring(canvas: &mut Canvas, hit: (f64, f64), grown: f64) {
    let radius = 16.0 * grown;
    let point = |k: f64| (hit.0 + (k * std::f64::consts::TAU / 14.0).cosine() * radius, hit.1 + (k * std::f64::consts::TAU / 14.0).sine() * radius * 0.5);
    for k in 0..14_u32 {
        streak(canvas, (point(f64::from(k)), point(f64::from(k + 1))), 0.6, scale(CRACK, 0.8 * grown));
    }
}

/// Shard `i`, `age` seconds after it broke free: a bright sliver falling and turning.
fn shard(canvas: &mut Canvas, hit: (f64, f64), i: u64, age: f64) {
    if !(0.0..2.0).contains(&age) {
        return;
    }
    let start = (hit.0 + (dice(i, 134) - 0.5) * 120.0, hit.1 + (dice(i, 135) - 0.5) * 40.0);
    let at = (start.0 + (dice(i, 136) - 0.5) * 20.0 * age, start.1 + 70.0 * age * age);
    let spin = age * (3.0 + 4.0 * dice(i, 137));
    let tip = (at.0 + spin.cosine() * 7.0, at.1 + spin.sine() * 3.5);
    streak(canvas, (at, tip), 1.3, scale(mix(CRACK, [0.6, 0.2, 0.2], 0.4), 1.0 - age / 2.0));
}
