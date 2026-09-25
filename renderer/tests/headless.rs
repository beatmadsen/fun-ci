//! AT-3.3: `--headless` replays a scenario and writes frames.jsonl,
//! frames/NNNN.png, sheet.png, frames.cast and stats.json.

use std::fs::{self, File};
use std::path::{Path, PathBuf};
use std::process::{Command, ExitStatus, Stdio};

use serde_json::Value;
use tempfile::TempDir;

const CELL: (u32, u32) = (8, 16);

fn scenario(name: &str) -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(format!("../contract/scenarios/{name}.jsonl"))
}

fn renderer(scenario: &Path, out: &Path) -> ExitStatus {
    let args = ["--headless", "--cols", "80", "--rows", "24", "--scenario"];
    let mut command = Command::new(env!("CARGO_BIN_EXE_fun-ci-renderer"));
    command.args(args).arg(scenario).arg("--out").arg(out).stdin(Stdio::null());
    command.status().unwrap()
}

fn headless(name: &str) -> TempDir {
    let out = tempfile::tempdir().unwrap();
    assert!(renderer(&scenario(name), out.path()).success());
    out
}

fn png_size(path: &Path) -> (u32, u32) {
    let info = png::Decoder::new(std::io::BufReader::new(File::open(path).unwrap())).read_info().unwrap();
    (info.info().width, info.info().height)
}

fn lines(path: &Path) -> Vec<Value> {
    fs::read_to_string(path).unwrap().lines().map(|l| serde_json::from_str(l).unwrap()).collect()
}

fn json(path: &Path) -> Value {
    serde_json::from_str(&fs::read_to_string(path).unwrap()).unwrap()
}

#[test]
fn frames_jsonl_has_one_line_per_tick() {
    assert_eq!(lines(&headless("running").path().join("frames.jsonl")).len(), 15);
}

#[test]
fn frames_jsonl_holds_each_frames_cell_grid() {
    let frame = &lines(&headless("running").path().join("frames.jsonl"))[0];
    assert_eq!(frame["cells"][14][2]["text"], "8");
}

#[test]
fn each_frame_png_is_the_grid_times_the_cell_size() {
    let out = headless("running");
    assert_eq!(png_size(&out.path().join("frames/0015.png")), (100 * CELL.0, 30 * CELL.1));
}

#[test]
fn a_frame_png_follows_a_resize() {
    let out = headless("resize-mid-animation");
    assert_eq!(png_size(&out.path().join("frames/0055.png")), (120 * CELL.0, 40 * CELL.1));
}

#[test]
fn every_tick_has_a_png() {
    assert_eq!(fs::read_dir(headless("running").path().join("frames")).unwrap().count(), 15);
}

#[test]
fn the_contact_sheet_tiles_every_frame_at_half_size() {
    let out = headless("running");
    assert_eq!(png_size(&out.path().join("sheet.png")), (4 * 50 * CELL.0, 4 * 15 * CELL.1));
}

#[test]
fn the_cast_is_asciicast_version_two() {
    assert_eq!(lines(&headless("running").path().join("frames.cast"))[0]["version"], 2);
}

#[test]
fn the_cast_is_as_wide_as_the_scenarios_first_frame() {
    assert_eq!(lines(&headless("running").path().join("frames.cast"))[0]["width"], 100);
}

#[test]
fn the_cast_records_a_resize() {
    let events = lines(&headless("resize-mid-animation").path().join("frames.cast"));
    assert_eq!(events.iter().filter(|e| e[1] == "r").count(), 1);
}

#[test]
fn the_cast_has_one_output_event_per_frame() {
    let events = lines(&headless("running").path().join("frames.cast"));
    assert_eq!(events.iter().filter(|e| e[1] == "o").count(), 15);
}

#[test]
fn stats_has_an_entry_per_frame() {
    let stats = json(&headless("running").path().join("stats.json"));
    assert_eq!(stats["frames"].as_array().unwrap().len(), 15);
}

#[test]
fn stats_counts_the_frames_each_animation_showed() {
    let stats = json(&headless("fail-explosion").path().join("stats.json"));
    assert_eq!(stats["animations"]["explosion"], 8);
}

#[test]
fn a_scenario_that_cannot_be_read_fails_the_run() {
    let out = tempfile::tempdir().unwrap();
    assert_eq!(renderer(&out.path().join("missing.jsonl"), out.path()).code(), Some(64));
}
