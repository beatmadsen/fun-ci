//! Success: fireworks over the hills. Shells climb on trails of sparks,
//! burst into falling, crackling stars, and PASSED shines out below.

use crate::art::math::Portable;
use super::lettering::{Style, title};
use super::sky::{hills, sky, stars};
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, streak};
use crate::art::noise::dice;
use crate::art::{Shade, float, mix, scale, seconds, smoothstep};

const LENGTH_MS: u64 = 4200;
const SHELLS: u64 = 8;
const STARS_PER_SHELL: u64 = 90;
const RISE: f64 = 0.6;
const BURN: f64 = 1.7;
const COLOURS: [Shade; 7] = [
    [1.3, 0.95, 0.35],
    [1.2, 0.3, 0.9],
    [0.35, 1.0, 1.25],
    [0.55, 1.25, 0.4],
    [1.35, 0.45, 0.25],
    [0.75, 0.55, 1.35],
    [1.2, 1.2, 1.2],
];

#[derive(Debug)]
pub struct Fireworks;

impl Scene for Fireworks {
    fn name(&self) -> &'static str {
        "success"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        sky(canvas);
        stars(canvas, t, (500, 0.0));
        (0..SHELLS).for_each(|shell| firework(canvas, shell, t));
        hills(canvas);
        passed(canvas, t);
    }
}

/// Shell `shell`: where it bursts, when it launches, and its colour.
fn shell_plan(canvas: &Canvas, shell: u64) -> ((f64, f64), f64, Shade) {
    let (width, height) = canvas.size();
    let burst = (width * (0.1 + 0.8 * dice(shell, 120)), height * (0.16 + 0.3 * dice(shell, 121)));
    let colour = COLOURS[usize::try_from(shell).unwrap_or(0) % COLOURS.len()];
    (burst, 0.05 + 0.33 * float(usize::try_from(shell).unwrap_or(0)) + 0.1 * dice(shell, 122), colour)
}

fn firework(canvas: &mut Canvas, shell: u64, t: f64) {
    let (burst, launch, colour) = shell_plan(canvas, shell);
    let since = t - launch;
    if since < 0.0 || since > RISE + BURN {
        return;
    }
    if since < RISE { climb(canvas, burst, since) } else { explode(canvas, (burst, colour), shell, since - RISE) }
}

fn climb(canvas: &mut Canvas, burst: (f64, f64), since: f64) {
    let ground = canvas.size().1;
    let at = |s: f64| (burst.0 + 6.0 * (1.0 - s / RISE), ground + (burst.1 - ground) * (1.0 - (1.0 - s / RISE).powi(2)));
    streak(canvas, (at((since - 0.12).max(0.0)), at(since)), 0.45, [0.45, 0.35, 0.2]);
    glow(canvas, at(since), 0.9, [1.3, 1.0, 0.6]);
}

fn explode(canvas: &mut Canvas, (burst, colour): ((f64, f64), Shade), shell: u64, age: f64) {
    glow(canvas, burst, 12.0, scale(colour, 0.5 * (1.0 - smoothstep(0.0, 0.35, age))));
    for star in 0..STARS_PER_SHELL {
        let id = shell * 1000 + star;
        let light = scale(mix(colour, [1.3, 1.25, 1.1], (1.0 - age * 3.0).max(0.0)), brightness(id, age));
        spark(canvas, (burst, id), age, light);
    }
}

/// Star `id` of the shell bursting at `burst`, with its trail.
fn spark(canvas: &mut Canvas, (burst, id): ((f64, f64), u64), age: f64, light: Shade) {
    let at = |a: f64| star_at(burst, id, a);
    streak(canvas, (at((age - 0.1).max(0.0)), at(age)), 0.4, scale(light, 0.3));
    glow(canvas, at(age), 0.55, scale(light, 0.8));
}

/// Where star `id` of a shell bursting at `burst` is `age` seconds after the burst.
fn star_at(burst: (f64, f64), id: u64, age: f64) -> (f64, f64) {
    let angle = dice(id, 123) * std::f64::consts::TAU;
    let speed = 70.0 * dice(id, 124).sqrt() + 8.0;
    let out = speed * (1.0 - (-age * 2.6).exponential()) / 2.6;
    (burst.0 + angle.cosine() * out, burst.1 + angle.sine() * out * 0.8 + 16.0 * age * age)
}

/// A star's light `age` seconds out: full, then fading and crackling.
fn brightness(id: u64, age: f64) -> f64 {
    let fade = 1.0 - smoothstep(BURN * 0.45, BURN, age);
    let crackle = if age > BURN * 0.5 && dice(id, (age * 18.0).floor().to_bits()) < 0.35 { 0.2 } else { 1.0 };
    fade * crackle
}

fn passed(canvas: &mut Canvas, t: f64) {
    let show = smoothstep(0.7, 1.2, t) * (1.0 - smoothstep(3.7, 4.2, t));
    let centre = (canvas.size().0 * 0.5, canvas.size().1 * 0.76);
    let fill = move |i: usize, x: f64, _: f64| mix([1.25, 0.95, 0.35], [1.35, 1.25, 0.8], shine(x - centre.0, i, t));
    let style = Style { pixel: 3.4, opacity: show, shadow: [0.05, 0.03, 0.08], fill: &fill, lift: &|i| 1.5 * (t * 5.0 - float(i) * 0.7).sine() };
    glow(canvas, centre, 26.0, scale([0.35, 0.25, 0.08], show));
    title(canvas, "PASSED", centre, &style);
}

/// A glint sweeping across the letters.
fn shine(dx: f64, _letter: usize, t: f64) -> f64 {
    (-((dx - (t - 1.2) * 90.0 + 80.0) / 10.0).powi(2)).exponential()
}
