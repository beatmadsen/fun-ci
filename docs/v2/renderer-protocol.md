# Renderer protocol, version 1

Transport: JSON Lines. One JSON object per line, UTF-8, `\n`-terminated.
Every message has a `"t"` (type). Unknown fields are ignored; unknown types are
answered with an `error` message and otherwise ignored (forward compatibility).

- Ruby → renderer: the renderer's **stdin**.
- Renderer → Ruby: the renderer's **stdout**.
- The renderer draws on `/dev/tty` (or, headless, into its frame recorder).
- The renderer's stderr is for diagnostics only; Ruby logs it, never parses it.

## Lifecycle

```
Ruby                                  renderer
 | spawn fun-ci-renderer               |
 | -- hello {v:1} -------------------> |
 | <------------- ready {v:1,cols,rows}|   (raw mode + alt screen entered)
 | -- board {...} -------------------> |   (renders immediately)
 | <-------------------- key {key:"j"} |
 | -- board {...} -------------------> |
 | <---------- resize {cols:120,rows:40}
 | -- board {...} (new page size) ---> |
 | -- event {name:"stage_failed"} ---> |   (plays an animation)
 | -- quit --------------------------> |
 |                                     |   (restores terminal, exits 0)
```

- EOF on stdin is treated as `quit`. The terminal is always restored.
- If `hello.v` isn't supported, the renderer replies `error{code:"version"}`,
  restores the terminal and exits 2.
- Ruby sends `board` whenever its data changes and at least every 5 s. The
  renderer redraws on its own clock (10 fps while anything animates or runs,
  otherwise once a second for relative times) using the latest `board`.

## Ruby → renderer

### `hello`
`{"t":"hello","v":1}`

### `board`
The full state to show. Always complete — never a diff.

```json
{"t":"board",
 "now": 1790000000,
 "project": "/home/erik/src/fun-ci",
 "streak": 7,
 "cursor": 0,
 "confirming": false,
 "has_more": true,
 "runs": [
   {"id": 42, "sha": "a3f7c01e...", "branch": "main",
    "status": "running", "started_at": 1789999880,
    "stages": [
      {"stage": "lint",  "status": "passed",  "duration_ms": 300},
      {"stage": "build", "status": "passed",  "duration_ms": 200},
      {"stage": "fast",  "status": "running", "started_at": 1789999990},
      {"stage": "slow",  "status": "pending"}
    ]}
 ]}
```

- `now` lets headless/test runs pin the clock; live runs send wall time and the
  renderer advances from there.
- `status` values (run): `pending`, `running`, `passed`, `failed`, `cancelled`.
  (stage): `pending`, `running`, `passed`, `failed`, `cancelled`, `timeout`.
- `sha` is always the full 40-hex SHA; shortening is the renderer's job.

### `event`
`{"t":"event","name":"<name>","run_id":42,"stage":"fast"}`

Names: `stage_failed`, `stage_passed`, `run_passed`, `run_failed`,
`running_started`, `running_stopped`. The renderer chooses the animation.
`run_id`/`stage` are present when meaningful.

### `quit`
`{"t":"quit"}`

## Renderer → Ruby

### `ready`
`{"t":"ready","v":1,"cols":120,"rows":40}`

### `key`
`{"t":"key","key":"j"}` — `key` is a single printable character, or one of
`up`, `down`, `enter`, `esc`, `ctrl_c`. Ruby's `KeyHandler` gives it meaning.
`ctrl_c` is delivered as a key (raw mode), and Ruby answers with `quit`.

### `resize`
`{"t":"resize","cols":120,"rows":40}` — Ruby recomputes the page size and sends
a fresh `board`.

### `error`
`{"t":"error","code":"parse"|"unknown_type"|"version","detail":"..."}`

## Headless mode

`fun-ci-renderer --headless --cols 80 --rows 24 --scenario <file> --out <dir>`

Reads messages from the scenario file instead of stdin (with `{"t":"tick","ms":100}`
lines advancing the fake clock) and writes, per frame:

- `frames.jsonl` — cell grid per frame (text, fg, bg, attrs) — machine checks
- `frames.cast` — asciicast v2 — human playback
- `sheet.svg` — contact sheet of all frames — agent/visual review
- `stats.json` — bytes written per frame, longest row, frames per animation

`tick` is only valid in headless mode.

## Contract fixtures

`contract/fixtures/*.jsonl` hold canonical conversations. The Ruby suite
asserts that `ConsoleSession` emits exactly the Ruby→renderer lines given the
recorded renderer→Ruby lines; the Rust suite asserts the reverse. Changing the
protocol means changing a fixture, which breaks both suites until both sides
agree.
