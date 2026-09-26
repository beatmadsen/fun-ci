//! AT-7.6: the header shows the streak of passed runs, and says so without
//! alarm when it is broken.

use serde_json::{Value, json};

use crate::support::boards::{TICK, last_screen};

fn with_streak(streak: &Value) -> String {
    json!({"t": "board", "now": 1_790_000_000, "streak": streak, "cursor": null, "runs": []}).to_string()
}

/// The header's second row after the boards with these streaks, a tick after each.
fn caption_row(streaks: &[Value]) -> String {
    let lines: Vec<String> = streaks.iter().flat_map(|streak| [with_streak(streak), TICK.to_string()]).collect();
    last_screen(&lines).text().lines().nth(1).unwrap().to_string()
}

#[test]
fn should_show_how_many_runs_in_a_row_have_passed() {
    assert!(caption_row(&[json!(7)]).contains("7 in a row!"));
}

#[test]
fn should_say_the_streak_is_broken_when_it_is_zero() {
    assert!(caption_row(&[json!(0)]).contains("streak broken"));
}

#[test]
fn should_show_no_streak_before_there_is_one() {
    assert!(!caption_row(&[Value::Null]).contains("row"));
}

#[test]
fn should_end_the_streak_two_columns_from_the_right_edge() {
    let row = caption_row(&[json!(7)]);
    let column = row.find("7 in a row!").map(|byte| row[..byte].chars().count());
    assert_eq!(column, Some(80 - 2 - "7 in a row!".len()));
}

#[test]
fn should_leave_no_old_digits_behind_when_the_streak_shrinks() {
    let row = caption_row(&[json!(12), json!(3)]);
    let before = row.find("3 in a row!").and_then(|byte| row[..byte].chars().last());
    assert!(before.is_some_and(|glyph| !glyph.is_ascii_digit()), "{row}");
}
