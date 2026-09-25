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

- EOF on stdin is treated as `quit`. The terminal is always restored: on EOF,
  `quit`, a panic, and SIGTERM, SIGHUP or SIGINT (which then exit with
  `128 + signal`, so 143 for SIGTERM).
- The renderer draws on `/dev/tty`; `--tty <path>` names another terminal
  device (tests use a pseudo-terminal this way).
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
    "project": "/home/erik/src/fun-ci",
    "status": "running", "started_at": 1789999880, "updated_at": 1789999990,
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
- `status` values (run): `pending`, `running`, `passed`, `failed`, `timeout`,
  `cancelled`. (stage): `pending`, `running`, `passed`, `failed`, `cancelled`,
  `timeout`.
- `sha` is always the full 40-hex SHA; shortening is the renderer's job.
- `updated_at` is the run's last status change; the row's "2m ago" counts from
  it.
- `project` (optional) is the path of the project the run belongs to. The
  renderer shows its basename in a colour chosen by CRC-32 of the basename, so
  a project keeps its colour across restarts.

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
`{"t":"error","code":"parse"|"unknown_type"|"version"|"terminal","detail":"..."}`

`terminal` means the renderer could not open `/dev/tty` or enter raw mode;
it exits 1 after sending it.

## Headless mode

`fun-ci-renderer --headless --cols 80 --rows 24 --scenario <file> --out <dir>`

Reads messages from the scenario file instead of stdin (with `{"t":"tick","ms":100}`
lines advancing the fake clock) and writes, per frame:

- `frames.jsonl`: cell grid per frame (text, fg, bg, attrs), for machine checks
- `frames/NNNN.png`: each frame rendered with a bundled monospace font, for
  visual review of layout and motion
- `sheet.png`: contact sheet of all frames
- `frames.cast`: asciicast v2, for human playback
- `stats.json`: per frame, bytes written, longest row, cells changed since the
  previous frame, luminance histogram, dark-cell share and hue spread; per
  animation, frame count

`tick` is only valid in headless mode. `--cols`/`--rows` are the terminal size
until the scenario's first `resize`. An unreadable scenario or output
directory exits 64 with the reason on stderr.

The details, which `renderer/tests/headless.rs` and `headless_measures.rs` pin:

- Each frame is what the terminal shows after feeding every frame so far to one
  `vt100` emulator. `frames.jsonl` has one object per frame:
  `{"frame":N,"cols":C,"rows":R,"cells":[[{"text","fg","bg","attrs"}...]...]}`,
  with colours `"default"`, `{"idx":N}` or `{"rgb":[r,g,b]}` and attrs a list
  of `bold`, `dim`, `italic`, `underline`, `inverse`.
- PNG cells are 8x16 pixels: the MIT-licensed `font8x8` bitmap font compiled
  into the binary, each row doubled; braille (the spinner) is drawn as dots.
  Colours are the xterm 256-colour palette, default foreground `#e5e5e5` on
  black; bold brightens colours 0-7 to 8-15, dim takes the foreground to 5/8.
- `sheet.png` tiles every frame at half size, `ceil(sqrt(n))` across.
- `frames.cast` starts at the first frame's size, has an `"o"` event per frame
  at its scenario time and an `"r"` event before a frame drawn at a new size.
- `stats.json` is `{"frames":[...],"animations":{"<name>":frames}}`. Per frame:
  `bytes`; `longest_row` (columns up to the last glyph of the longest row);
  `cells_changed` (cells that differ from the previous frame, or non-blank
  cells for the first frame and after a resize); `luminance_histogram` (pixel
  counts in eight buckets of 32 luminance levels, Rec. 709 weights);
  `dark_cell_share` (share of cells whose visible colour, the foreground of a
  glyph or else the background, has luminance under 64); `hue_spread` (how
  many 30-degree hue sectors the glyphs' colours cover, greys and near-black
  excluded). `animations` counts the frames each header animation was shown.

### Scenario files

`contract/scenarios/<name>.jsonl` are the scenarios both renderers replay: the
Ruby capture tool (AT-2.6) and `--headless --scenario` (AT-3.3, AT-3.4).

- Every scenario starts with `{"t":"resize","cols":C,"rows":R}`. In a scenario,
  `resize` means *the terminal changed size*; it takes effect at the next frame.
- `board` replaces the state and sets the clock to its `now`. It doesn't draw.
- `event` is sent alongside the `board` that caused it. It may carry
  `"animation":"<name>"` (e.g. `"success"`, `"explosion"`) to pin a choice the
  renderer would otherwise make at random. Live Ruby never sends that field.
- `{"t":"tick","ms":100}` advances the clock and draws **exactly one frame**.
  Frames are numbered from 1 in tick order, which is what lets two renderers
  be compared frame by frame.

The Ruby oracle's frames are `contract/golden/<name>/NNNN.bytes` (0001, 0002,
...). Frame 0001 includes the initial screen clear. Frames are cumulative: feed
them in order to one terminal emulator and compare its grid after each.

## Contract fixtures

`contract/fixtures/*.jsonl` hold canonical conversations. The Ruby suite
asserts that `ConsoleSession` emits exactly the Ruby→renderer lines given the
recorded renderer→Ruby lines; the Rust suite asserts the reverse. Changing the
protocol means changing a fixture, which breaks both suites until both sides
agree.

Each line is an object with exactly one key:

- `{"ruby": <message>}`: a line Ruby sends the renderer.
- `{"renderer": <message>}`: a line the renderer sends Ruby.
- `{"state": {"now": <epoch>, "runs": [...]}}`: Ruby-side context the renderer
  never sees: what the database holds (runs as `BoardData` reads them from
  SQLite) and the clock. The first `state` line is the starting point; each
  later one is what Ruby's next poll finds.

The Ruby replay (`test/acceptance/test_contract_fixtures.rb`) feeds in the
`renderer` lines and compares the whole conversation, both directions in
order, with the fixture.
