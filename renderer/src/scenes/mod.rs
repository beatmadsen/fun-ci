//! The header's scenes.

mod aurora;
mod bricks;
mod calm;
mod celebrate;
mod explosion;
mod fireflies;
mod fireworks;
mod flash;
mod gears;
mod idle;
mod lettering;
mod leprechauns;
mod ripple;
mod rocket;
mod running;
mod sky;
mod sweep;
mod tick;
mod warning;
mod yay;

use crate::animation::Scene;

/// Every built-in scene.
pub static ALL: [&dyn Scene; 16] = [
    &aurora::Aurora,
    &fireflies::Fireflies,
    &bricks::Bricks,
    &calm::Calm,
    &warning::Warning,
    &gears::Gears,
    &ripple::Ripple,
    &sweep::Sweep,
    &celebrate::Celebrate,
    &explosion::Explosion,
    &flash::Flash,
    &idle::Idle,
    &leprechauns::Leprechauns,
    &running::Running,
    &fireworks::Fireworks,
    &yay::Yay,
];
