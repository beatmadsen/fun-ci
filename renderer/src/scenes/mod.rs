//! The header's scenes.

mod bricks;
mod celebrate;
mod explosion;
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
mod yay;

use crate::animation::Scene;

/// Every built-in scene.
pub static ALL: [&dyn Scene; 12] = [
    &bricks::Bricks,
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
