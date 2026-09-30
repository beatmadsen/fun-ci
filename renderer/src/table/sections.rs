//! The table's sections: each project's rows under its name. Ruby sends the
//! rows a project at a time (renderer-protocol.md, `board`), so a section is
//! a run of consecutive rows of one project.

use crate::format::project_name;
use crate::model::Run;

/// One project's rows, in the order they came.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Section<'a> {
    /// The project's directory name, empty for rows that name none.
    pub project: String,
    pub runs: Vec<&'a Run>,
}

/// `runs` as sections, a new one wherever the project changes.
#[must_use]
pub fn sections(runs: &[Run]) -> Vec<Section<'_>> {
    let mut out: Vec<Section> = Vec::new();
    for run in runs {
        let project = run.commit.project.as_deref().map(project_name).unwrap_or_default();
        match out.last_mut().filter(|section| section.project == project) {
            Some(section) => section.runs.push(run),
            None => out.push(Section { project, runs: vec![run] }),
        }
    }
    out
}

/// A project's label: its name in capitals, a space between each letter.
#[must_use]
pub fn spaced(name: &str) -> String {
    name.to_uppercase().chars().map(String::from).collect::<Vec<_>>().join(" ")
}
