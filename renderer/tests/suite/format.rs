//! Formatting matches the 1.x Ruby renderer (`DurationFormatter`,
//! `RelativeTime`, `RowFormatter.format_project`); expected values were
//! produced by running the Ruby code.

use fun_ci_renderer::format::{age, duration, project_colour, project_name, short_sha, stage_label};

macro_rules! cases {
    ($($name:ident: $actual:expr => $expected:expr;)*) => {
        $(#[test] fn $name() { assert_eq!($actual, $expected); })*
    };
}

cases! {
    a_duration_under_a_second_shows_tenths: duration(300) => "0.3s";
    a_whole_second_duration_has_no_decimals: duration(1000) => "1s";
    a_tie_rounds_to_even_like_sprintf: duration(1250) => "1.2s";
    a_duration_above_a_tie_rounds_up: duration(1350) => "1.4s";
    a_duration_just_under_a_minute_rounds_like_sprintf: duration(59_999) => "60.0s";
    a_minute_or_more_shows_minutes_and_padded_seconds: duration(62_500) => "1m02";
    exactly_a_minute_shows_zero_seconds: duration(60_000) => "1m00";
    an_hour_is_shown_in_minutes: duration(3_600_000) => "60m00";
    under_a_minute_ago_is_just_now: age(1000, 1_059_999) => "just now";
    a_minute_ago_counts_minutes: age(1000, 1_060_000) => "1m ago";
    just_under_an_hour_ago_counts_minutes: age(1000, 1_000_000 + 3_599_000) => "59m ago";
    an_hour_ago_counts_hours: age(1000, 1_000_000 + 3_600_000) => "1h ago";
    a_time_in_the_future_is_just_now: age(1000, 995_000) => "just now";
    a_sha_is_shortened_to_seven_characters: short_sha("a3f7c01e9b2d") => "a3f7c01";
    a_sha_shorter_than_seven_characters_is_kept: short_sha("a3f") => "a3f";
    a_project_is_named_by_its_directory: project_name("/src/fun-ci") => "fun-ci";
    fun_ci_gets_colour_four: project_colour("fun-ci") => 35;
    agent_tome_gets_colour_seven: project_colour("agent-tome") => 92;
    intent_record_gets_colour_five: project_colour("intent-record") => 36;
    the_fast_stage_is_labelled_fast: stage_label("fast") => Some("Fast");
    an_unknown_stage_has_no_label: stage_label("deploy") => None;
}
