//! The seed for the animation choices: different from run to run, and never
//! zero, which the generator would never leave.

use std::time::{Duration, UNIX_EPOCH};

use fun_ci_renderer::animator::seed_at;

#[test]
fn a_seed_at_a_whole_second_is_not_zero() {
    assert_ne!(seed_at(UNIX_EPOCH + Duration::from_secs(7)), 0);
}

#[test]
fn a_seed_one_nanosecond_past_a_second_is_not_zero() {
    assert_ne!(seed_at(UNIX_EPOCH + Duration::from_nanos(1)), 0);
}

#[test]
fn seeds_at_different_times_differ() {
    assert_ne!(seed_at(UNIX_EPOCH + Duration::from_nanos(2)), seed_at(UNIX_EPOCH + Duration::from_nanos(4)));
}

#[test]
fn a_time_before_the_epoch_still_gives_a_seed() {
    assert_ne!(seed_at(UNIX_EPOCH - Duration::from_secs(1)), 0);
}
