//! The table's sections: a project's rows under its name, in the order Ruby
//! sends the rows (renderer-protocol.md, `board`).

use fun_ci_renderer::model::Run;
use fun_ci_renderer::table::sections::{sections, spaced};
use serde_json::json;

fn run(id: u64, project: Option<&str>) -> Run {
    serde_json::from_value(json!({"id": id, "sha": format!("{id:040}"), "branch": "main", "project": project,
                                  "status": "passed", "updated_at": 0, "stages": []}))
    .unwrap()
}

fn ids(runs: &[Run]) -> Vec<Vec<u64>> {
    sections(runs).iter().map(|section| section.runs.iter().map(|run| run.id).collect()).collect()
}

#[test]
fn a_label_is_the_project_s_name_in_letter_spaced_capitals() {
    assert_eq!(spaced("fun-ci"), "F U N - C I");
}

#[test]
fn consecutive_rows_of_a_project_make_one_section() {
    let runs = [run(1, Some("/src/a")), run(2, Some("/src/a")), run(3, Some("/src/b"))];

    assert_eq!(ids(&runs), [vec![1, 2], vec![3]]);
}

#[test]
fn a_section_is_named_by_the_project_s_directory() {
    let runs = [run(1, Some("/src/strings-kata"))];

    assert_eq!(sections(&runs)[0].project, "strings-kata");
}

#[test]
fn rows_without_a_project_make_a_section_with_no_name() {
    let runs = [run(1, None)];

    assert_eq!(sections(&runs)[0].project, "");
}
