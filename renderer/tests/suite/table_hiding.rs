//! Hiding a daily or weekly job from the footer (design.md, The console;
//! acceptance-tests.md, AT-13.29 to AT-13.31): the key that hides the job
//! under the cursor, the question it asks, what the footer says of the jobs
//! hidden, and what a hidden job's row says once they are shown.

use fun_ci_renderer::model::{Board, Job};
use fun_ci_renderer::table::footer::keys;
use fun_ci_renderer::table::hiding::aside;
use fun_ci_renderer::table::job_words::{said, said_briefly};
use serde_json::{Value, json};

const NOW: i64 = 1_790_000_000;

fn job(name: &str, more: &Value) -> Value {
    let mut job = json!({"name": name, "cadence": "weekly", "status": "failed", "run_id": 9, "sha": "9e0b1d4a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4",
                         "branch": "main", "started_at": NOW - 600, "updated_at": NOW - 60});
    job.as_object_mut().unwrap().extend(more.as_object().unwrap().clone());
    job
}

/// A passed branch, then `jobs`, the cursor on row `cursor`.
fn board(jobs: &[Value], cursor: usize, more: &Value) -> Board {
    let run = json!({"id": 1, "sha": "d4e5f67a3f7c01e9b2d4c6f8a1b3c5d7e9f0a2b4", "branch": "main", "status": "passed", "updated_at": NOW, "stages": []});
    let mut board = json!({"now": NOW, "cursor": cursor, "runs": [run], "jobs": jobs});
    board.as_object_mut().unwrap().extend(more.as_object().unwrap().clone());
    serde_json::from_value(board).unwrap()
}

fn hidden(how: &str) -> Job {
    serde_json::from_value(job("soak", &json!({"hidden": how}))).unwrap()
}

#[test]
fn the_keys_offer_to_hide_the_job_under_the_cursor() {
    assert_eq!(keys(&board(&[job("soak", &json!({}))], 1, &json!({}))).keys, [("j/k", "move"), ("h", "hide"), ("q", "quit")]);
}

#[test]
fn the_keys_offer_to_hide_nothing_while_the_cursor_is_on_a_branch() {
    assert_eq!(keys(&board(&[job("soak", &json!({}))], 0, &json!({}))).keys, [("j/k", "move"), ("q", "quit")]);
}

#[test]
fn the_keys_offer_to_show_a_hidden_job_under_the_cursor() {
    assert!(keys(&board(&[job("soak", &json!({"hidden": "snoozed"}))], 1, &json!({}))).keys.contains(&("h", "show")));
}

#[test]
fn hiding_a_job_asks_about_it_by_name() {
    assert_eq!(keys(&board(&[job("soak", &json!({}))], 1, &json!({"hiding": true}))).question.as_deref(), Some("Hide soak?"));
}

#[test]
fn hiding_a_job_is_answered_with_snooze_ignore_or_no_each_saying_for_how_long() {
    let answers = [("s", "snooze until its next run"), ("i", "ignore until shown again"), ("n", "no")];

    assert_eq!(keys(&board(&[job("soak", &json!({}))], 1, &json!({"hiding": true}))).keys, answers);
}

#[test]
fn the_footer_says_how_many_jobs_are_hidden_and_which_key_shows_them() {
    assert_eq!(aside(&board(&[], 0, &json!({"hidden_jobs": 2}))), "a shows 2 hidden jobs");
}

#[test]
fn one_hidden_job_is_said_in_the_singular() {
    assert_eq!(aside(&board(&[], 0, &json!({"hidden_jobs": 1}))), "a shows 1 hidden job");
}

#[test]
fn no_hidden_job_says_nothing() {
    assert_eq!(aside(&board(&[job("soak", &json!({}))], 0, &json!({}))), "");
}

// A question takes every key but its answers.
#[test]
fn the_footer_names_no_key_for_hidden_jobs_while_it_asks_how_to_hide_one() {
    assert_eq!(aside(&board(&[job("soak", &json!({}))], 1, &json!({"hidden_jobs": 2, "hiding": true}))), "");
}

#[test]
fn the_footer_names_no_key_for_hidden_jobs_while_it_confirms_a_cancel() {
    assert_eq!(aside(&board(&[job("soak", &json!({}))], 1, &json!({"hidden_jobs": 2, "confirming": true}))), "");
}

#[test]
fn hidden_jobs_on_the_board_say_which_key_hides_them_again() {
    assert_eq!(aside(&board(&[job("soak", &json!({"hidden": "ignored"}))], 0, &json!({"hidden_jobs": 1}))), "a hides hidden jobs");
}

#[test]
fn a_snoozed_job_says_until_when() {
    assert_eq!(said(&hidden("snoozed"), NOW * 1000), "snoozed until its next run");
}

#[test]
fn an_ignored_job_says_so() {
    assert_eq!(said(&hidden("ignored"), NOW * 1000), "ignored");
}

#[test]
fn a_job_hidden_in_a_way_this_renderer_does_not_know_says_hidden() {
    assert_eq!(said(&hidden("muted"), NOW * 1000), "hidden");
}

#[test]
fn on_a_narrow_screen_a_snoozed_job_says_so_briefly() {
    assert_eq!(said_briefly(&hidden("snoozed"), NOW * 1000), "snoozed");
}

#[test]
fn on_a_narrow_screen_an_ignored_job_says_so() {
    assert_eq!(said_briefly(&hidden("ignored"), NOW * 1000), "ignored");
}

#[test]
fn hiding_a_job_names_its_project_too_when_the_board_holds_more_than_one() {
    let board = board(&[job("soak", &json!({"project": "/src/tool"}))], 1, &json!({"hiding": true}));

    assert_eq!(keys(&board).question.as_deref(), Some("Hide tool · soak?"));
}

#[test]
fn cancelling_a_job_names_its_project_too_when_the_board_holds_more_than_one() {
    let board = board(&[job("soak", &json!({"project": "/src/tool", "status": "running"}))], 1, &json!({"confirming": true}));

    assert_eq!(keys(&board).question.as_deref(), Some("Cancel tool · soak (9e0b1d4)?"));
}
