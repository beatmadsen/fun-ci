//! The session's clocks: the wall clock counts from its start, and a still
//! clock stays at its time.

use std::time::{Duration, Instant};

use fun_ci_renderer::inputs::{Clock, StillClock};
use fun_ci_renderer::live_io::WallClock;

#[test]
fn the_wall_clock_counts_the_milliseconds_since_it_started() {
    let two_seconds_ago = Instant::now().checked_sub(Duration::from_secs(2)).unwrap();
    assert!(WallClock::started_at(two_seconds_ago).now_ms() >= 2_000);
}

#[test]
fn a_still_clock_shows_its_time() {
    assert_eq!(StillClock(1_234).now_ms(), 1_234);
}
