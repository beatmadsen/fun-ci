//! frames.cast: the frames as an asciicast v2 recording, for playback with
//! `asciinema play`.

use serde_json::{Value, json};

use crate::replay::TickFrame;

/// The recording: a header line, then an output event per frame, preceded by
/// a resize event wherever the terminal size changed.
#[must_use]
pub fn asciicast(frames: &[TickFrame]) -> String {
    let first = frames.first().map_or((80, 24), |frame| frame.size);
    let header = json!({"version": 2, "width": first.0, "height": first.1, "env": {"TERM": "xterm-256color"}});
    let lines: Vec<String> = std::iter::once(header).chain(events(frames, first)).map(|v| v.to_string()).collect();
    lines.join("\n") + "\n"
}

fn events(frames: &[TickFrame], first: (u16, u16)) -> Vec<Value> {
    let with_resizes = frames.iter().scan(first, |size, frame| {
        let resize = resize_event(frame, *size);
        *size = frame.size;
        Some(resize.into_iter().chain([output_event(frame)]))
    });
    with_resizes.flatten().collect()
}

fn output_event(frame: &TickFrame) -> Value {
    json!([seconds(frame), "o", String::from_utf8_lossy(&frame.bytes)])
}

fn resize_event(frame: &TickFrame, previous: (u16, u16)) -> Option<Value> {
    let (cols, rows) = frame.size;
    (frame.size != previous).then(|| json!([seconds(frame), "r", format!("{cols}x{rows}")]))
}

fn seconds(frame: &TickFrame) -> f64 {
    f64::from(u32::try_from(frame.elapsed_ms).unwrap_or(u32::MAX)) / 1000.0
}
