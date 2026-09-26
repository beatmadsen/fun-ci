//! The header's scenes.

mod celebrate;
mod explosion;
mod fireworks;
mod flash;
mod idle;
mod lettering;
mod leprechauns;
mod rocket;
mod running;
mod sky;
mod yay;

use crate::animation::Scene;

/// Every built-in scene.
pub static ALL: [&dyn Scene; 8] = [
    &celebrate::Celebrate,
    &explosion::Explosion,
    &flash::Flash,
    &idle::Idle,
    &leprechauns::Leprechauns,
    &running::Running,
    &fireworks::Fireworks,
    &yay::Yay,
];
