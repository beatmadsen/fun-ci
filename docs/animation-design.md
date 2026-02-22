# Animation Design: Party-Mode Stage Transitions

## 1. Overview

Fun-CI's TUI currently renders stage results as static colored text: green for pass, bold red
for fail. This document designs a transient animation system that celebrates successes and
dramatizes failures -- turning the dashboard into something you actually want to watch.

The design is constrained by:

- Raw terminal mode (`\r\n` line endings, `\e[K` per line, `\e[J` after frame)
- Monospace font, ANSI 256 colors only (no true-color assumption)
- The existing 0.1s fast-refresh cycle (10 fps) during running pipelines
- Screen width between 60 and ~200 columns
- Max 150 lines per file, max 4 instance variables per class
- No external dependencies (pure ANSI escape codes)


## 2. Animation Inventory

### 2.1 FAILURE: "The Explosion"

A three-part animation that fires simultaneously:

**Part A -- Stage Column Flanking Blasts**

Expanding debris erupts on both sides of the failed stage text. The failed stage name and
FAIL label remain visible in the center as an anchor point, flanked by outward-spreading
particle clouds.

```
Frame 1 (0.0s):   ...  *Fast FAIL 6.2s*  ...
Frame 2 (0.1s):   ... .*Fast FAIL 6.2s*. ...
Frame 3 (0.2s):   ..*. *Fast FAIL 6.2s* .*..
Frame 4 (0.3s):   *.+' *Fast FAIL 6.2s* '+.*
Frame 5 (0.4s):   ' .  *Fast FAIL 6.2s*  . '
Frame 6 (0.5s):   .    *Fast FAIL 6.2s*    .
Frame 7 (0.6s):        *Fast FAIL 6.2s*
```

Particle characters cycle through: `*` `+` `'` `.` ` ` (bright to fading).

Color per frame:
- Frame 1-2: `\e[1;31m` (bold red) on the particles
- Frame 3-4: `\e[38;5;208m` (orange, 256-color) on the particles
- Frame 5-6: `\e[38;5;52m` (dark red, fading) on the particles
- Frame 7: particles gone, stage text remains in its normal bold red

**Part B -- Header Explosion Banner**

The header bar (row 0) flashes and overlays a centered explosion message. The `fun-ci`
title text is temporarily replaced.

```
Frame 1 (0.0s):  normal header
Frame 2 (0.1s):  [red bg]            * BOOM *             [/red bg]
Frame 3 (0.2s):  [orange bg]       * * BOOM * *           [/orange bg]
Frame 4 (0.3s):  [dark red bg]   . * * BOOM * * .         [/dark red bg]
Frame 5 (0.4s):  [charcoal bg]  ' . *  BOOM  * . '       [/charcoal bg]
Frame 6 (0.5s):  [charcoal bg]     .    BOOM    .         [/charcoal bg]
Frame 7 (0.6s):  normal header (restored)
```

Background colors for the banner:
- Frame 2: `\e[48;5;124m` (dark red bg)
- Frame 3: `\e[48;5;166m` (orange bg)
- Frame 4: `\e[48;5;52m` (very dark red bg)
- Frame 5-6: `\e[48;5;236m` (normal charcoal bg, particles dimming)

**Part C -- Footer Shockwave**

The footer line briefly shakes and shows an impact message, then restores.

```
Frame 1 (0.0s):  normal footer
Frame 2 (0.1s):  [bold red] >>> STAGE FAILED <<< [/bold red]
Frame 3 (0.2s):  [red]      >> stage failed <<   [/red]
Frame 4 (0.3s):  [dim red]   > stage failed <    [/dim red]
Frame 5 (0.4s):  normal footer (restored)
```

The word "stage" is replaced with the actual stage name, e.g. `>>> FAST FAILED <<<`.


### 2.2 SUCCESS: "The Fireworks"

Fires when a pipeline run transitions to `completed` (all stages passed).

**Part A -- Stage Column Sparkle Sweep**

Each completed stage gets a brief left-to-right sparkle sweep over its existing green text.
The sweeps are staggered: lint first, then build, then fast, then slow -- 2 frames apart
each, creating a visual "wave" across the columns.

Sparkle overlay characters: `*` then `+` then back to normal text.

For a single stage column, the sweep looks like (shown over "Lint 0.1s"):

```
Frame 1:   *int 0.1s     (sparkle on column 0 of stage text)
Frame 2:   L*nt 0.1s     (sparkle moves right)
Frame 3:   Li*t 0.1s
Frame 4:   Lin* 0.1s
Frame 5:   Lint*0.1s
Frame 6:   Lint +.1s     (trailing + fades behind *)
Frame 7:   Lint 0*1s
...continues to end of stage text...
```

Color:
- `*` sparkle: `\e[1;33m` (bold yellow -- gold flash)
- `+` trail: `\e[32m` (green -- same as normal, blends back)
- Stage text remains `\e[32m` (green) where not covered by sparkle

Stagger timing (all at 0.1s per frame):
- Lint sweep starts at frame 0
- Build sweep starts at frame 2
- Fast sweep starts at frame 4
- Slow sweep starts at frame 6

Total animation: ~16 frames (1.6s), but most of the visual action happens in the first
second. The last few frames are just the final trail fading on the slow column.

**Part B -- Header Celebration Banner**

The header transitions through a party sequence:

```
Frame 1  (0.0s):  normal header
Frame 2  (0.1s):  [green bg]           ALL PASSED           [/green bg]
Frame 3  (0.2s):  [green bg]     *  *  ALL PASSED  *  *     [/green bg]
Frame 4  (0.3s):  [green bg]   * .  .  ALL PASSED  .  . *   [/green bg]
Frame 5  (0.4s):  [yellow bg]  . '  '  ALL PASSED  '  ' .   [/yellow bg]
Frame 6  (0.5s):  [green bg]   '       ALL PASSED       '   [/green bg]
Frame 7  (0.6s):  [green bg]           ALL PASSED           [/green bg]
Frame 8  (0.7s):  normal header with updated streak count
```

Background colors:
- Frame 2-4: `\e[48;5;22m` (dark green bg)
- Frame 5: `\e[48;5;58m` (dark yellow bg -- flash pop)
- Frame 6-7: `\e[48;5;22m` (dark green bg)

**Part C -- Footer Confetti Burst**

The footer briefly shows a confetti line, then restores.

```
Frame 1 (0.0s):  normal footer
Frame 2 (0.1s):  [bold green]  * * * NICE! * * *  [/bold green]
Frame 3 (0.2s):  [green]  . + . * NICE! * . + .   [/green]
Frame 4 (0.3s):  [dim]    ' . + .  nice  . + . '  [/dim]
Frame 5 (0.4s):  normal footer
```


### 2.3 STAGE PASS (Individual): "The Checkmark Flash"

Fires when an individual stage transitions from `running` to `completed`, while the
pipeline is still running (i.e., the fast suite passes and slow is still going).

This is a quick, subtle animation -- just a brief flash on the single stage column to
acknowledge the moment without overwhelming.

```
Frame 1 (0.0s):  [bold yellow] Lint 0.1s [/bold yellow]     (flash to gold)
Frame 2 (0.1s):  [bold green]  Lint 0.1s [/bold green]      (snap to bright green)
Frame 3 (0.2s):  [green]       Lint 0.1s [/green]           (settle to normal green)
```

No header or footer effects. Just a 0.3s column flash. Quick and satisfying.


### 2.4 TIMEOUT: "The Slow Fade"

Fires when a stage transitions to `timed_out`. Subdued compared to failure -- this is
disappointing but not catastrophic.

```
Frame 1 (0.0s):  [bold yellow] Fast TIMEOUT 10s [/bold yellow]   (flash bright)
Frame 2 (0.1s):  [yellow]      Fast TIMEOUT 10s [/yellow]        (dim slightly)
Frame 3 (0.2s):  [bold yellow] Fast TIMEOUT 10s [/bold yellow]   (pulse back up)
Frame 4 (0.3s):  [yellow]      Fast TIMEOUT 10s [/yellow]        (settle)
```

Header shows a brief amber flash:
```
Frame 1 (0.0s):  normal header
Frame 2 (0.1s):  [yellow bg]         TIMED OUT          [/yellow bg]
Frame 3 (0.2s):  [dim yellow bg]     timed out          [/dim yellow bg]
Frame 4 (0.3s):  normal header (restored)
```


## 3. Timing Specification

| Animation         | Frames | Duration | FPS | Trigger                              |
|--------------------|--------|----------|-----|--------------------------------------|
| Failure explosion  | 7      | 0.7s     | 10  | Stage status -> `failed`             |
| Success fireworks  | 16     | 1.6s     | 10  | Pipeline status -> `completed`       |
| Stage pass flash   | 3      | 0.3s     | 10  | Stage status -> `completed` (mid-run)|
| Timeout pulse      | 4      | 0.4s     | 10  | Stage status -> `timed_out`          |

All animations run at the existing FAST_REFRESH rate of 0.1s per frame (10 fps). No new
timer is needed; the animation system piggybacks on the render loop that already runs at
this speed when a pipeline is active.

When no pipeline is running and no animation is active, the TUI reverts to SLOW_REFRESH
(5.0s). An active animation should keep the refresh interval at FAST_REFRESH until all
animation frames are exhausted.


## 4. Screen Placement

### 4.1 Coordinate System

The TUI renders top-to-bottom in a streaming fashion. Row positions are implicit: the
header is always row 0, then a blank line, then pipeline rows (each row + a blank separator
line), then a blank line, then the footer.

For a board with 3 pipeline runs at width 80:

```
Row 0:  [====== HEADER (full width) ======]
Row 1:  (blank)
Row 2:  pipeline run 1 (most recent)
Row 3:  (blank separator)
Row 4:  pipeline run 2
Row 5:  (blank separator)
Row 6:  pipeline run 3
Row 7:  (blank)
Row 8:  [footer keybindings]
```

### 4.2 Stage Column Position Within a Row

A formatted row looks like (ANSI stripped for illustration):

```
  a3f7c01  main  Lint 0.1s  Build 0.3s  Fast 1.8s  Slow 47s  PASSED  just now
  ^                ^                                           ^
  col 2            col ~16 (varies with branch name length)    col ~60
  commit/branch    stage columns start here                    status
```

The stage columns have variable start positions because branch names vary. The animation
system must calculate column offsets dynamically based on the actual formatted text.

**Approach**: The `RowFormatter` should return structured data (not just a flat string)
that includes character offsets for each stage column. This allows the animation overlay
to know exactly where to place particles. See Section 7.3 for the proposed interface.

### 4.3 Flanking Blast Placement (Failure)

The flanking blasts extend outward from the edges of the failed stage's column span.

Given a stage "Fast FAIL 6.2s" starting at column 38:
- Stage text occupies columns 38-52 (14 chars)
- Left blast extends from column 37 leftward (max 4 chars): columns 34-37
- Right blast extends from column 53 rightward (max 4 chars): columns 53-56

If a blast would go past column 0 or past the screen width, it is clipped. Never wrap.

### 4.4 Header Banner Placement

The header banner replaces the entire header line (row 0). The banner text is
center-justified within the screen width. The header restoration at the end of the
animation re-renders the normal header with streak text.

### 4.5 Footer Banner Placement

The footer banner replaces the entire footer line (last rendered row). Center-justified
within the screen width.


## 5. State Machine

### 5.1 Animation Lifecycle

```
                 trigger event
                      |
                      v
             +--[AnimationActive]--+
             |    frame_index=0    |
             |                     |
             |  each render_frame: |
             |    frame_index += 1 |
             |                     |
             |  frame_index >=     |
             |  total_frames?      |
             |     |          |    |
             |    yes         no   |
             |     |          |    |
             |     v          +----+
             +--[Idle]
```

### 5.2 Detection: How Transitions Are Spotted

The TUI currently calls `@board_data.runs` every frame and formats the results. It has no
memory of previous state. To detect transitions, the animation system needs to diff
consecutive snapshots.

**Proposed approach -- `TransitionDetector`:**

A new class that accepts the current runs array and compares it against a stored previous
snapshot. It returns a list of transition events:

```ruby
events = @transition_detector.detect(current_runs)
# => [
#   { type: :stage_completed, run_index: 0, stage: "lint" },
#   { type: :pipeline_failed, run_index: 0 },
# ]
```

Transitions detected:
- `:stage_completed` -- a stage went from `running` to `completed`
- `:stage_failed` -- a stage went from `running` to `failed`
- `:stage_timed_out` -- a stage went from `running` to `timed_out`
- `:pipeline_completed` -- a pipeline went from `running` to `completed`
- `:pipeline_failed` -- a pipeline went from `running` to `failed`

The detector stores only the previous runs' `{id, status, stages: [{stage, status}]}`
-- a minimal fingerprint, not the full data.

### 5.3 Animation Queue

Multiple animations can be active simultaneously (e.g., a stage passes while a previous
stage's pass flash is still playing). The system maintains a list of active animations,
each with its own frame counter.

When a new event fires and an animation of the same type is already playing for the same
run, the new animation replaces the old one (reset frame counter). Different types on
different runs can coexist.

Header/footer slots are exclusive: only one animation can control the header at a time.
If a failure explosion starts while a success celebration is still using the header, the
failure wins (higher priority). Priority order:

1. Failure explosion (highest)
2. Timeout pulse
3. Success fireworks
4. Stage pass flash (no header effect, so no conflict)

### 5.4 Interaction With Normal Render Loop

The render cycle becomes:

```
render_frame:
  1. move_cursor_home
  2. advance spinner
  3. detect transitions (compare current vs previous snapshot)
  4. queue new animations for any detected transitions
  5. advance all active animation frame counters
  6. render header (with animation overlay if active)
  7. render blank line
  8. for each row:
       render row (with animation overlays on relevant stage columns)
       render blank separator
  9. render footer (with animation overlay if active)
  10. clear_below
  11. expire any animations that have reached their last frame
```

### 5.5 Refresh Interval Override

Currently `refresh_interval` returns `FAST_REFRESH` when any pipeline is `running`, and
`SLOW_REFRESH` otherwise. With animations, it should also return `FAST_REFRESH` when any
animation is active, even if all pipelines are terminal. This keeps the animation smooth
even after the pipeline has finished.

```ruby
def refresh_interval
  return FAST_REFRESH if @animator.any_active?
  runs = @board_data.runs
  any_running = runs.any? { |r| r[:status] == "running" }
  any_running ? FAST_REFRESH : SLOW_REFRESH
end
```


## 6. Color Scheme (ANSI Codes)

### 6.1 Failure Palette

| Element             | ANSI Code            | Description         |
|----------------------|----------------------|---------------------|
| Bright explosion     | `\e[1;31m`           | Bold red            |
| Hot debris           | `\e[38;5;208m`       | Orange (256-color)  |
| Fading embers        | `\e[38;5;52m`        | Dark red            |
| Header flash bg      | `\e[48;5;124m`       | Dark red background |
| Header warm bg       | `\e[48;5;166m`       | Orange background   |
| Header fade bg       | `\e[48;5;52m`        | Very dark red bg    |
| Footer text          | `\e[1;31m`           | Bold red            |
| BOOM banner text     | `\e[1;37m`           | Bold white          |

### 6.2 Success Palette

| Element             | ANSI Code            | Description          |
|----------------------|----------------------|----------------------|
| Sparkle head         | `\e[1;33m`           | Bold yellow (gold)   |
| Sparkle trail        | `\e[32m`             | Green (blends back)  |
| Header flash bg      | `\e[48;5;22m`        | Dark green background|
| Header pop bg        | `\e[48;5;58m`        | Dark yellow bg       |
| Banner text          | `\e[1;37m`           | Bold white           |
| Confetti chars       | `\e[1;32m`           | Bold green           |
| Confetti fading      | `\e[2;32m`           | Dim green            |

### 6.3 Timeout Palette

| Element             | ANSI Code            | Description          |
|----------------------|----------------------|----------------------|
| Bright pulse         | `\e[1;33m`           | Bold yellow          |
| Settled              | `\e[33m`             | Yellow               |
| Header flash bg      | `\e[48;5;58m`        | Dark yellow bg       |

### 6.4 Stage Pass Flash Palette

| Element             | ANSI Code            | Description          |
|----------------------|----------------------|----------------------|
| Gold flash           | `\e[1;33m`           | Bold yellow          |
| Bright green         | `\e[1;32m`           | Bold green           |
| Settled green        | `\e[32m`             | Green (normal)       |


## 7. Terminal Constraints

### 7.1 Raw Mode and Line Endings

All output must use `\r\n`, not bare `\n`. The existing `Screen#println` already handles
this. Animation overlays must flow through `Screen#println` or an equivalent method that
guarantees the `\e[K\r\n` suffix.

Animation frames must never partially write a line. Each line is written atomically as a
complete string, just as the current renderer does. This prevents visual tearing.

### 7.2 Width Handling

Animation effects adapt to screen width:

- **Narrow terminals (< 80 cols)**: Flanking blasts are reduced to 2 chars per side instead
  of 4. Header/footer banners shorten their particle borders. If the banner text itself
  does not fit (< 40 cols), skip header/footer animations entirely and only play column
  animations.

- **Wide terminals (> 120 cols)**: Flanking blasts can extend to 6 chars per side. Banner
  text stays centered but does not grow -- extra space is padding.

- **Resize during animation**: If `SIGWINCH` fires mid-animation, the animation is
  immediately cancelled (all frame counters reset to 0, animations removed). The next
  render frame will be a clean non-animated frame. This is simpler and more robust than
  trying to recalculate column offsets mid-animation.

### 7.3 Cursor Positioning

The current renderer works by moving the cursor home (`\e[H`) and overwriting from the top.
Animations do NOT use absolute cursor positioning (`\e[row;colH`) to place individual
characters. Instead, the animation system composes complete lines and passes them to
`Screen#println`. This keeps the rendering model simple and consistent.

Concretely: the animation layer is a **line-level overlay**, not a pixel-level overlay. For
each line that has an active animation, the animation system produces the entire modified
line string. The renderer uses this instead of the normal line.

### 7.4 `\e[K` (Erase to End of Line)

Every `println` already appends `\e[K` before `\r\n`. Animation lines that are shorter than
the previous frame's line will automatically have trailing content erased. No special
handling needed.

### 7.5 `\e[J` (Erase Below)

Called once after the full frame via `clear_below`. Animation frames do not change the
total number of lines rendered, so this continues to work correctly. (The header and footer
are always exactly one line each; animation replaces their content but not their count.)


## 8. Integration Points

### 8.1 New Files

| File                                | Purpose                      | Est. Lines |
|--------------------------------------|------------------------------|------------|
| `lib/fun_ci/animation.rb`           | Animation data (type, frames, frame_index, run_index) | ~40 |
| `lib/fun_ci/animator.rb`            | Queue, advance, expire, overlay compositor            | ~120 |
| `lib/fun_ci/transition_detector.rb` | Diff consecutive board snapshots                      | ~60 |
| `lib/fun_ci/animation_frames.rb`    | Frame data for each animation type (the ASCII art)    | ~140 |

All files stay under the 150-line limit.

### 8.2 Changes to Existing Files

**`lib/fun_ci/admin_tui.rb`**

- Add `@animator` instance variable (Animator.new) -- this is the 5th ivar, which means
  one existing ivar needs to be eliminated or the constraint relaxed. The best candidate
  is `@running`, which can become a local in `run`. Alternatively, `@confirm_cancel` could
  be pushed into a small `ConfirmationState` object that `@animator` also manages, keeping
  the AdminTui at 4 ivars.

- In `render_once`: call `@animator.detect_and_queue(runs)` after fetching runs, then pass
  the animator to the screen/rendering methods so they can apply overlays.

- In `refresh_interval`: also check `@animator.any_active?`.

- In `resize`: call `@animator.cancel_all` when width changes.

**`lib/fun_ci/screen.rb`**

- `render_header` gains an optional `overlay:` keyword. When provided, it replaces the
  normal header content with the overlay string (already colored by the animator).

- `render_footer` gains an optional `overlay:` keyword, same pattern.

- `render_board` gains an optional `row_overlays:` keyword -- a hash of
  `{row_index => modified_line_string}`. When an index is present in the hash, the overlay
  string is used instead of the normal row.

**`lib/fun_ci/row_formatter.rb`**

- `format` returns a richer object (or the existing string gains metadata via a small
  wrapper) that includes character offset ranges for each stage column. Possible approaches:

  Option A: Return a `FormattedRow` struct with `.text` and `.stage_spans` (a hash of
  `{stage_name => start..end}`). Callers that just need the string call `.text` or `.to_s`.

  Option B: Keep returning a string. Add a separate class method
  `RowFormatter.stage_column_offsets(run)` that returns the offsets without the full format.
  The animator calls this when it needs to position overlays.

  Option A is cleaner. The `FormattedRow` would respond to `to_s` and `lstrip` so existing
  call sites in `Screen#render_board` continue to work without changes.

**`lib/fun_ci/ansi.rb`**

- Add new color methods:
  - `Ansi.orange(text)` -- `\e[38;5;208m`
  - `Ansi.dark_red(text)` -- `\e[38;5;52m`
  - `Ansi.bg_dark_red(text)` -- `\e[48;5;124m`
  - `Ansi.bg_orange(text)` -- `\e[48;5;166m`
  - `Ansi.bg_very_dark_red(text)` -- `\e[48;5;52m`
  - `Ansi.bg_dark_green(text)` -- `\e[48;5;22m`
  - `Ansi.bg_dark_yellow(text)` -- `\e[48;5;58m`
  - `Ansi.dim_green(text)` -- `\e[2;32m`

### 8.3 DI Seams for Testing

**Animator receives a `clock:` lambda** (defaults to `-> { Time.now }`) so tests can
control time without real sleeps. However, since animations are frame-counted (not
time-based), the clock is not strictly needed -- frame advancement happens on each
`render_frame` call. Tests simply call `render_frame` N times.

**TransitionDetector is pure**: it takes the current snapshot and returns events. No side
effects, no IO. Fully testable with unit data.

**AnimationFrames is pure data**: each class method returns an array of frame hashes. Fully
testable by asserting frame counts, character content, and ANSI codes.

**Animator receives `transition_detector:` via constructor** so tests can inject a fake
that returns predetermined events.

### 8.4 Test Strategy

| Test File                          | Scope                                    |
|-------------------------------------|------------------------------------------|
| `test/unit/test_transition_detector.rb` | Snapshot diffing, event generation    |
| `test/unit/test_animation_frames.rb`    | Frame counts, content, ANSI codes     |
| `test/unit/test_animator.rb`            | Queue, advance, expire, overlay       |
| `test/integration/test_admin_tui_animations.rb` | End-to-end: insert runs, render, check output |

Key test patterns:

- **Transition detection**: Create two board snapshots (before/after), call `detect`, assert
  the correct events. No DB, no IO.

- **Frame content**: Call `AnimationFrames.failure_explosion` and assert frame 0 contains
  `*`, frame 6 is empty particles, total frame count is 7, etc.

- **Overlay composition**: Give the Animator a known animation state and a row string, call
  `compose_row_overlay`, assert the output string has the expected characters at the
  expected positions.

- **Integration**: Use the existing DatabaseTestSetup pattern. Create a run, transition a
  stage to failed, call `render_once` 7 times, capture output, assert that early frames
  contain explosion characters and late frames do not.

All tests are deterministic: no real time, no threading, no polling. Frame advancement is
purely a function of how many times `render_frame` is called.


## 9. Worked Example: Failure Flow

Here is the complete visual sequence when the `fast` stage fails on a run, from the user's
perspective. Terminal width is 80.

### Before (steady state, fast is running):

```
 fun-ci                                                       3 in a row!

  a3f7c01  main  Lint 0.1s  Build 0.3s  Fast [spinner] 6s  Slow --  RUNNING  2s

  j/k move   c cancel   q quit
```

### Frame 1 (fast fails -- transition detected, animation starts):

```
 fun-ci                                                       3 in a row!

  a3f7c01  main  Lint 0.1s  Build 0.3s  *Fast FAIL 6.2s*  Slow --  FAILED  just now

  j/k move   c cancel   q quit
```

Stage text snaps to bold red. Flanking `*` appears on both sides in bold red.

### Frame 2:

```
[dark red bg]                        * BOOM *

  a3f7c01  main  Lint 0.1s  Build 0.3s .*Fast FAIL 6.2s*. Slow --  FAILED  just now

[bold red]                    >>> FAST FAILED <<<
```

Header replaced with BOOM banner. Footer replaced with failure callout.
Flanking particles expand one column outward.

### Frame 3:

```
[orange bg]                      * * BOOM * *

  a3f7c01  main  Lint 0.1s  Build 0.3s.+' *Fast FAIL 6.2s* '+.Slow --  FAILED  just now

[red]                       >> fast failed <<
```

Particles now in orange, expanding further. Header shifts to orange bg.

### Frame 4:

```
[very dark red bg]             . * * BOOM * * .

  a3f7c01  main  Lint 0.1s  Build*0.3s ' *Fast FAIL 6.2s* ' Slow --  FAILED  just now

[dim red]                      > fast failed <
```

Debris chars turn dark red, some overlap neighboring stage text. This is fine -- the
overlap is part of the "blast" feel. The original text reasserts next frame.

### Frame 5:

```
[charcoal bg]                '  .    BOOM    .  '

  a3f7c01  main  Lint 0.1s  Build 0.3s . Fast FAIL 6.2s .  Slow --  FAILED  just now

  j/k move   c cancel   q quit
```

Footer restored. Particles fading (dark red, sparse). Header dimming.

### Frame 6:

```
[charcoal bg]                   .    BOOM    .

  a3f7c01  main  Lint 0.1s  Build 0.3s  Fast FAIL 6.2s .  Slow --  FAILED  just now

  j/k move   c cancel   q quit
```

Almost done. Single fading dot on the right side.

### Frame 7 (animation complete, steady state):

```
 fun-ci                                                     Streak broken

  a3f7c01  main  Lint 0.1s  Build 0.3s  Fast FAIL 6.2s  Slow --  FAILED  just now

  j/k move   c cancel   q quit
```

Normal rendering resumes. Streak counter has updated to "Streak broken".
The `Fast FAIL 6.2s` text remains bold red as its normal settled state.


## 10. Worked Example: Success Flow

The `slow` stage completes, making the entire pipeline `completed`.

### Before (slow is running):

```
 fun-ci                                                       3 in a row!

  c82fa19  feat/parser  Lint 0.1s  Build 0.3s  Fast 1.8s  Slow [spinner] 42s  RUNNING  42s

  j/k move   c cancel   q quit
```

### Frame 1 (pipeline completes -- both :stage_completed and :pipeline_completed fire):

```
 fun-ci                                                       3 in a row!

  c82fa19  feat/parser  Lint 0.1s  Build 0.3s  Fast 1.8s  Slow 47s  PASSED  just now

  j/k move   c cancel   q quit
```

Text snaps to green. Sparkle sweep begins on Lint column.

### Frame 2:

```
[dark green bg]                     ALL PASSED

  c82fa19  feat/parser  L*nt 0.1s  Build 0.3s  Fast 1.8s  Slow 47s  PASSED  just now

[bold green]               * * * NICE! * * *
```

Header celebration. Footer confetti. Sparkle `*` moves through "Lint".

### Frame 3:

```
[dark green bg]               *  *  ALL PASSED  *  *

  c82fa19  feat/parser  Li*t 0.1s  B*ild 0.3s  Fast 1.8s  Slow 47s  PASSED  just now

[green]                  . + . * NICE! * . + .
```

Sparkle sweep advances. Build sweep starts (staggered by 2 frames).

### Frames 4-8 (sparkle sweeps continue across all four stage columns):

The `*` character rolls left-to-right through each stage's text, staggered.
Header particles expand and fade. Footer restores at frame 5.

### Frame 16 (animation complete):

```
 fun-ci                                                       4 in a row!

  c82fa19  feat/parser  Lint 0.1s  Build 0.3s  Fast 1.8s  Slow 47s  PASSED  just now

  j/k move   c cancel   q quit
```

Streak has incremented. Everything is steady green.


## 11. Edge Cases

### 11.1 Rapid Successive Failures

If two stages fail in quick succession (e.g., parallel lint and build both fail), each
triggers its own flanking blast, and the header shows BOOM for the first one. The second
failure's header animation replaces the first (same priority) -- frame counter resets.

### 11.2 Success Immediately After Failure

If a slow suite completes successfully while a failure animation is still playing (the
pipeline was already marked failed due to fast), the failure animation takes priority for
the header. The success animation is suppressed entirely -- there is no "success" to
celebrate if the pipeline failed.

### 11.3 Very Long Branch Names

When the branch name is very long, stage columns are pushed far right. Flanking blasts
that would extend past the screen width are clipped. If the failed stage column is within
4 characters of the right edge, only the left blast appears.

### 11.4 Cursor on the Animating Row

If the user's cursor (j/k selection) is on the row that is animating, the `>` cursor
marker is preserved. The animation overlay replaces stage column content but keeps the
`> ` prefix intact.

### 11.5 Multiple Visible Runs Animating

Each run's animation is independent. It is possible (though unusual) for one run to be
celebrating success while another is exploding. The header/footer show whichever animation
has highest priority. Stage column animations are per-row and never conflict.

### 11.6 Cancel During Animation

If the user presses `c` (cancel) or `q` (quit) during an animation, the keypress takes
effect immediately. Animations do not block input. Cancellation and quit have priority
over visual flourishes.

### 11.7 Empty Board

If the board is empty (no runs), no transitions can be detected, so no animations fire.
The empty state is never animated.

### 11.8 First Render

On the very first `render_once`, the TransitionDetector has no previous snapshot. It should
return an empty events list (no transitions detected), so no animations play for data that
was already in a terminal state before the TUI launched. Only live transitions trigger
animations.


## 12. Accessibility Considerations

### 12.1 Reduced Motion

Add a `--no-animations` flag to `fun-ci console` that disables all animations. The flag
sets `@animator` to a `NullAnimator` that returns empty overlays and `any_active? = false`.
This is also useful for CI environments where the TUI might be used for debugging via
script/expect.

### 12.2 Screen Reader Compatibility

Screen readers cannot parse ANSI animations. The animations are purely decorative -- all
meaningful information (PASSED, FAILED, stage times) is present in the normal non-animated
text. The animations add flair but no informational content that is not also conveyed by
the static rendering.


## 13. Implementation Order

Suggested build order to get incremental value:

1. **TransitionDetector** -- pure logic, fully unit-testable, no visual output
2. **AnimationFrames** -- pure data, fully unit-testable
3. **Animator** -- orchestration, unit-testable with fakes
4. **Ansi color additions** -- trivial
5. **Stage pass flash** (simplest visual, 3 frames) -- first visible result
6. **Failure explosion** (most dramatic, 7 frames)
7. **Success fireworks** (most complex, 16 frames with staggered sweeps)
8. **Timeout pulse** (straightforward variation)
9. **Screen overlay API** (render_header/footer/board overlay keywords)
10. **AdminTui integration** (wire it all together)
11. **--no-animations flag**
12. **RowFormatter FormattedRow wrapper** (needed for precise column positioning)

Steps 1-4 can be built and tested without touching any existing file.
Steps 5-8 add the animation content.
Steps 9-12 integrate into the running TUI.

Each step is independently testable and shippable. The TUI works fine without animations
at every intermediate step.
