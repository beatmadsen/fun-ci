//! Success: two leprechauns dance a jig on a green hill at golden hour, a
//! rainbow sweeps across the sky, and coins leap from the pot of gold.

use crate::art::math::Portable;
use crate::animation::Scene;
use crate::art::canvas::Canvas;
use crate::art::light::{glow, streak};
use crate::art::noise::{dice, value};
use crate::art::sprite::Sprite;
use crate::art::{Shade, add, hue, mix, scale, seconds, smoothstep};

const LENGTH_MS: u64 = 4400;
const PIXEL: f64 = 2.4;
const PALETTE: &[(char, Shade)] = &[
    ('k', [0.05, 0.36, 0.12]),
    ('x', [0.04, 0.04, 0.05]),
    ('y', [1.0, 0.82, 0.25]),
    ('s', [1.0, 0.76, 0.58]),
    ('e', [0.1, 0.06, 0.05]),
    ('o', [0.95, 0.42, 0.08]),
    ('g', [0.12, 0.62, 0.22]),
    ('b', [0.2, 0.1, 0.05]),
];
const STEP: [&str; 17] = [
    "   kkkkk   ", "   kkkkk   ", "   xxyxx   ", " kkkkkkkkk ", "   sssss   ", "   seses   ", "  osssssso ", "  ooooooo  ", "   ooooo   ",
    " ggggggggg ", "sggggggggs ", " gggggggg  ", " xxxxyxxx  ", "  ggggggg  ", "  gg   gg  ", " gg     gg ", "bb       bb",
];
const KICK: [&str; 17] = [
    "   kkkkk   ", "   kkkkk   ", "   xxyxx   ", " kkkkkkkkk ", "   sssss   ", "   seses   ", "  osssssso ", "  ooooooo  ", "   ooooo   ",
    " ggggggggg ", "s ggggggggs", "  gggggggg ", "  xxxyxxxx ", "  ggggggg  ", "  gg   gggb", "  gg     bb", " bbb       ",
];

#[derive(Debug)]
pub struct Leprechauns;

impl Scene for Leprechauns {
    fn name(&self) -> &'static str {
        "leprechauns"
    }

    fn length_ms(&self) -> Option<u64> {
        Some(LENGTH_MS)
    }

    fn paint(&self, canvas: &mut Canvas, t_ms: u64) {
        let t = seconds(t_ms);
        let pot = (canvas.size().0 * 0.5, canvas.size().1 * 0.8);
        meadow(canvas, t);
        coins(canvas, pot, t);
        pot_of_gold(canvas, pot, t);
        dancers(canvas, pot, t);
    }
}

/// The golden-hour sky, the rainbow across it and the hill below.
fn meadow(canvas: &mut Canvas, t: f64) {
    sky(canvas);
    rainbow(canvas, t);
    hill(canvas);
}

fn sky(canvas: &mut Canvas) {
    let (width, height) = canvas.size();
    canvas.map(|x, y, _| {
        let k = y / height;
        let sun = (-((x - width * 0.85).hypotenuse(y - height * 0.7) / 40.0).powi(2)).exponential();
        add(mix([0.14, 0.3, 0.62], [0.98, 0.7, 0.45], smoothstep(0.1, 0.9, k)), scale([1.0, 0.8, 0.45], sun * 0.8))
    });
}

/// The rainbow, revealed left to right over the first second.
fn rainbow(canvas: &mut Canvas, t: f64) {
    let (width, height) = canvas.size();
    let (centre, radius) = ((width * 0.5, height * 1.35), (width * 0.45).min(150.0));
    let reveal = std::f64::consts::PI * (1.0 - smoothstep(0.1, 1.2, t));
    canvas.map(|x, y, pixel| {
        let band = (radius - (x - centre.0).hypotenuse(y - centre.1)) / 20.0;
        mix(pixel, spectrum(band), band_cover(band) * swept((centre.0 - x, centre.1 - y), reveal))
    });
}

/// How much of the rainbow shows `band` of the way across it: soft at both edges.
fn band_cover(band: f64) -> f64 {
    smoothstep(0.0, 0.08, band) * smoothstep(1.0, 0.92, band) * 0.6
}

/// 1.0 where the arc has been drawn: from the left round to the angle `reveal`.
fn swept((dx, dy): (f64, f64), reveal: f64) -> f64 {
    f64::from(u8::from(dy.arctangent2(dx) >= reveal))
}

/// Red at the outside edge of the band (0.0) round to violet at the inside (1.0).
fn spectrum(k: f64) -> Shade {
    hue(k.clamp(0.0, 1.0) * 0.78)
}

fn hill(canvas: &mut Canvas) {
    let height = canvas.size().1;
    canvas.map(|x, y, pixel| {
        let edge = height * 0.74 + 7.0 * value(x / 60.0, 5.0, 160);
        let grass = mix([0.35, 0.78, 0.25], [0.08, 0.38, 0.12], smoothstep(edge, height, y));
        mix(pixel, grass, (y - edge + 0.5).clamp(0.0, 1.0))
    });
}

fn pot_of_gold(canvas: &mut Canvas, pot: (f64, f64), t: f64) {
    canvas.map(|x, y, pixel| {
        let (dx, dy) = ((x - pot.0) / 15.0, (y - pot.1 + 2.0) / 11.0);
        let iron = ((1.0 - dx.hypotenuse(dy)) * 11.0).clamp(0.0, 1.0) * f64::from(u8::from(dy > -0.55));
        let pot = mix(pixel, scale([0.12, 0.12, 0.14], 0.6 + 0.8 * (-dx - dy).max(0.0)), iron);
        mix(pot, glinting_gold(x, y, t), ((1.0 - (dx * 1.05).hypotenuse((dy + 0.6) * 2.4)) * 10.0).clamp(0.0, 1.0))
    });
    glow(canvas, (pot.0, pot.1 - 8.0), 12.0, [0.35, 0.25, 0.05]);
}

/// Heaped gold coins, glinting as the light moves over them.
fn glinting_gold(x: f64, y: f64, t: f64) -> Shade {
    scale([1.0, 0.75, 0.2], 0.75 + 0.45 * value(x / 2.0, y / 2.0 + t * 3.0, 161))
}

fn coins(canvas: &mut Canvas, pot: (f64, f64), t: f64) {
    for i in 0..16_u64 {
        let flip = (t * 9.0 + dice(i, 164) * 6.0).cosine().abs();
        let at = coin_at(i, pot, t);
        streak(canvas, ((at.0 - 2.2 * flip, at.1), (at.0 + 2.2 * flip, at.1)), 1.1, scale([1.2, 0.85, 0.2], 0.4 + 0.6 * flip));
        glow(canvas, (at.0 - flip, at.1 - 1.0), 0.8, scale([1.5, 1.4, 1.0], flip.powi(6)));
    }
}

/// Where coin `i` is on its leap out of the pot at `pot`, `t` seconds in.
fn coin_at(i: u64, pot: (f64, f64), t: f64) -> (f64, f64) {
    let age = (t * 0.8 + dice(i, 162)).fract() * 1.3;
    let angle = -std::f64::consts::FRAC_PI_2 + (dice(i, 163) - 0.5) * 1.6;
    (pot.0 + angle.cosine() * 60.0 * age, pot.1 - 10.0 + angle.sine() * 75.0 * age + 55.0 * age * age)
}

/// A leprechaun either side of the pot, a quarter-beat apart, facing it.
fn dancers(canvas: &mut Canvas, pot: (f64, f64), t: f64) {
    dancer(canvas, (pot.0 - 58.0, pot.1), t, false);
    dancer(canvas, (pot.0 + 58.0, pot.1), t + 0.25, true);
}

/// A leprechaun at `feet`, kicking on alternate beats, hopping, facing left when `mirrored`.
fn dancer(canvas: &mut Canvas, feet: (f64, f64), beat: f64, mirrored: bool) {
    let rows = if (beat * 4.0).floor() % 2.0 < 1.0 { STEP } else { KICK };
    let flipped: Vec<String> = rows.iter().map(|row| if mirrored { row.chars().rev().collect() } else { (*row).to_string() }).collect();
    let refs: Vec<&str> = flipped.iter().map(String::as_str).collect();
    let hop = (beat * std::f64::consts::PI * 4.0).sine().abs() * 5.0;
    let sprite = Sprite { rows: &refs, palette: PALETTE };
    sprite.stamp(canvas, (feet.0 - 5.5 * PIXEL, feet.1 - 17.0 * PIXEL - hop + 4.0), PIXEL);
}
