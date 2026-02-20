# fun-ci Admin TUI -- Wireframe Sketches

One screen. A glanceable status board with life to it.

The TUI is not a drill-down monitoring system. It's a board you pull
up, glance at, maybe cancel something, and close. Like a departure
board at a train station -- you don't click on a train to see its
route. You look, you know, you go.

Throughout this document, color and animation annotations appear in
{curly braces} since ASCII can't render them directly.


---

## The Main (and Only) Screen -- Happy Path

Everything is green. Life is good.

```
{entire header bar: white text on dark charcoal background}
 fun-ci                                        {green}7 in a row!

{default terminal background below}

  a3f7c01  main           {green}Build 0.3s  Fast 1.8s  Slow 47s     {green, bold}PASSED   {dim}2m ago
  e92b4da  fix/login-bug  {green}Build 0.2s  Fast 0.9s  Slow 1m02    {green, bold}PASSED  {dim}14m ago
  7c1d8f3  feat/search    {green}Build 0.1s  Fast 2.1s  Slow 2m31    {green, bold}PASSED  {dim}38m ago
  bb40e62  main           {green}Build 0.2s  Fast 0.4s  Slow 33s     {green, bold}PASSED   {dim}1h ago
  51f9a2c  feat/search    {green}Build 0.1s  Fast 1.2s  Slow 55s     {green, bold}PASSED   {dim}2h ago
  d004e71  chore/deps     {green}Build 0.3s  Fast 0.7s  Slow 41s     {green, bold}PASSED   {dim}3h ago
  f38a910  main           {green}Build 0.2s  Fast 1.1s  Slow 1m18    {green, bold}PASSED   {dim}5h ago




{dim, bottom of screen}
  j/k move   c cancel   q quit
```

**Design notes:**

- No table headers. The layout is self-evident once you see one row.
  Commit, branch, three stages with times, outcome, when. Every row
  reads like a sentence.
- The streak ("7 in a row!") is the fun reward element in the header.
  It's always visible. When the number is high, it feels good.
- Stage times are green when they passed. Coloring the numbers
  themselves (not a separate status column) means you can scan the
  board for color without reading. A wall of green = everything fine.
- "PASSED" is bold green. It pops but doesn't scream.
- Relative time is dim -- secondary information, always available but
  never competing for attention.
- The footer is minimal and dim. Three keys. That's the entire
  interface. No "Press ? for help" -- there's nothing to help with.


---

## In Progress -- Slow Suite Running

Something is happening right now. The board should feel alive.

```
{white on charcoal}
 fun-ci                                        {green}4 in a row!

{default background}

{highlight row: subtle light background tint, whole row}
  c82fa19  feat/parser    {green}Build 0.2s  {green}Fast 2.4s  {cyan, animated}Slow {spinner} 34s    {cyan, bold}RUNNING {dim}just now
  a3f7c01  main           {green}Build 0.3s  Fast 1.8s  Slow 47s     {green, bold}PASSED   {dim}2m ago
  e92b4da  fix/login-bug  {green}Build 0.2s  Fast 0.9s  Slow 1m02    {green, bold}PASSED  {dim}14m ago
  7c1d8f3  feat/search    {green}Build 0.1s  Fast 2.1s  Slow 2m31    {green, bold}PASSED  {dim}38m ago
  bb40e62  main           {green}Build 0.2s  Fast 0.4s  Slow 33s     {green, bold}PASSED   {dim}1h ago
  51f9a2c  feat/search    {green}Build 0.1s  Fast 1.2s  Slow 55s     {green, bold}PASSED   {dim}2h ago
  d004e71  chore/deps     {green}Build 0.3s  Fast 0.7s  Slow 41s     {green, bold}PASSED   {dim}3h ago




{dim}
  j/k move   c cancel   q quit
```

**Design notes:**

- The `{spinner}` is an animated braille spinner (frames:
  `"` `"` `"` `"` `"` `"` `"` `"`). It cycles at ~100ms.
  This single detail makes the whole screen feel alive. When
  something is running, you can SEE it running. No ambiguity.
- The elapsed time (`34s`) ticks up live, updating every second.
  Combined with the spinner, this creates a subtle pulse that draws
  the eye to the active row without being distracting.
- The RUNNING row has a faint background highlight (e.g., a slightly
  lighter terminal background) to separate it from the settled rows.
  This is optional but nice if the terminal supports 256 colors.
- Completed stages on the running row (Build and Fast) show green --
  they're done and happy. Only the active stage is cyan.
- The streak counter still shows in the header. The streak counts
  consecutive PASSED runs; a RUNNING run neither breaks nor extends
  it. The streak only changes when a run completes.


---

## In Progress -- Fast Suite Running (Early Pipeline)

The run just started. Build is done, fast suite is going.

```
{white on charcoal}
 fun-ci                                        {green}4 in a row!

{default background}

  c82fa19  feat/parser    {green}Build 0.2s  {cyan, animated}Fast {spinner} 3s   {dim}Slow --       {cyan, bold}RUNNING {dim}just now
  a3f7c01  main           {green}Build 0.3s  Fast 1.8s  Slow 47s     {green, bold}PASSED   {dim}2m ago
  e92b4da  fix/login-bug  {green}Build 0.2s  Fast 0.9s  Slow 1m02    {green, bold}PASSED  {dim}14m ago
  7c1d8f3  feat/search    {green}Build 0.1s  Fast 2.1s  Slow 2m31    {green, bold}PASSED  {dim}38m ago




{dim}
  j/k move   c cancel   q quit
```

**Design notes:**

- Slow shows `--` in dim. It hasn't started yet. The dim color makes
  it visually recede -- you can see it's there but not interesting yet.
- The spinner is on the Fast stage now. Wherever the spinner is, that's
  where the action is. Your eye goes right to it.


---

## Failure -- Fast Suite Failed

The latest run broke. Failures should be immediately obvious
without being anxiety-inducing.

```
{white on charcoal}
 fun-ci                                        Streak broken

{default background}

{red-tinted row background}
  91de003  fix/nil-crash  {green}Build 0.1s  {red, bold}Fast FAIL 6.2s  {dim}Slow --    {red, bold}FAILED   {dim}3m ago
  47a0b8e  feat/parser    {green}Build 0.2s  Fast 1.8s  {red, bold}Slow FAIL 4m51      {red, bold}FAILED  {dim}11m ago
  a3f7c01  main           {green}Build 0.3s  Fast 1.8s  Slow 47s     {green, bold}PASSED  {dim}18m ago
  e92b4da  fix/login-bug  {green}Build 0.2s  Fast 0.9s  Slow 1m02    {green, bold}PASSED  {dim}30m ago
  7c1d8f3  feat/search    {green}Build 0.1s  Fast 2.1s  Slow 2m31    {green, bold}PASSED  {dim}54m ago




{dim}
  j/k move   c cancel   q quit
```

**Design notes:**

- "FAIL" replaces the time in the stage where things broke. The time
  still shows, but after FAIL: `Fast FAIL 6.2s` reads as "Fast suite
  failed at 6.2 seconds." Compact and scannable.
- Red and bold for failed stages and the FAILED status. Red draws
  the eye. You can see which row and which stage broke at a glance.
- Slow shows `--` because the pipeline stopped after Fast failed.
  Dim, not red -- it didn't fail, it just never happened.
- The streak in the header switches to "Streak broken" in the normal
  header color (not red -- the header shouldn't alarm, the rows
  should). Understated but honest.
- The second row shows a Slow suite failure for contrast. Same
  pattern: the failing stage shows `FAIL` in red, the rest is normal.


---

## Failure -- Timed Out

The fast suite exceeded its 10-second budget and was killed.
This looks different from a test failure because the user's
response is different.

```
{white on charcoal}
 fun-ci                                        Streak broken

{default background}

{yellow-tinted row background}
  d4e5f67  feat/search    {green}Build 0.2s  {yellow, bold}Fast TIMEOUT 10s  {dim}Slow --  {yellow, bold}TIMED OUT {dim}just now
  a3f7c01  main           {green}Build 0.3s  Fast 1.8s  Slow 47s     {green, bold}PASSED   {dim}18m ago
  e92b4da  fix/login-bug  {green}Build 0.2s  Fast 0.9s  Slow 1m02    {green, bold}PASSED   {dim}30m ago




{dim}
  j/k move   c cancel   q quit
```

**Design notes:**

- Yellow, not red. A timeout is a design signal ("your suite is too
  heavy"), not a code bug. Yellow says "pay attention" without the
  severity of red. This matches the spec's framing: "This is a
  feature, not a bug."
- `TIMEOUT 10s` tells the user the budget was the limit, and the
  status reads `TIMED OUT` rather than `FAILED`. Different cause,
  different label, different color. The user instantly knows this
  wasn't a test failure.
- Note: I'm recommending TimedOut as a distinct displayed state
  (which the spec's failure modes table already uses) even though
  the state machine lists only four states. The TUI should surface
  this distinction.


---

## Queued / Scheduled Runs

Multiple commits landed. One is running, others are waiting.

```
{white on charcoal}
 fun-ci                                        {green}4 in a row!

{default background}

  {dim}f001ba2  feat/cache     {dim, italic}Scheduled...                                              {dim}just now
  {dim}a8b3c01  feat/cache     {dim, italic}Scheduled...                                              {dim}just now
  d4e5f67  feat/search    {green}Build 0.2s  {cyan, animated}Fast {spinner} 7s   {dim}Slow --       {cyan, bold}RUNNING {dim}12s ago
  c82fa19  feat/parser    {green}Build 0.2s  Fast 2.4s  Slow 3m01    {green, bold}PASSED   {dim}4m ago
  91de003  fix/nil-crash  {green}Build 0.1s  {red, bold}Fast FAIL 6.2s  {dim}Slow --    {red, bold}FAILED   {dim}7m ago




{dim}
  j/k move   c cancel   q quit
```

**Design notes:**

- Scheduled rows are entirely dim. They're not interesting yet --
  they're just waiting. The word "Scheduled..." with trailing
  ellipsis and italic gives them a patient, anticipatory feel.
  No stage columns, no times. There's nothing to show yet.
- The `c` key cancels whichever row the cursor is on. Scheduled rows
  can be cancelled (removed from the queue). Running rows can be
  cancelled (process killed, marked as Cancelled). Completed rows
  can't be cancelled -- `c` does nothing, no error.
- This is the only screen where cancellation really matters. If
  you committed twice by accident, you want to kill the old one.


---

## Cancel Confirmation

The one moment of necessary friction. Cancelling a running job
kills a process -- the user should confirm.

```
{white on charcoal}
 fun-ci                                        {green}4 in a row!

{default background}

  {dim}f001ba2  feat/cache     {dim, italic}Scheduled...                                              {dim}just now
  {dim}a8b3c01  feat/cache     {dim, italic}Scheduled...                                              {dim}just now
  d4e5f67  feat/search    {green}Build 0.2s  {cyan, animated}Fast {spinner} 7s   {dim}Slow --       {cyan, bold}RUNNING {dim}12s ago
  c82fa19  feat/parser    {green}Build 0.2s  Fast 2.4s  Slow 3m01    {green, bold}PASSED   {dim}4m ago
  91de003  fix/nil-crash  {green}Build 0.1s  {red, bold}Fast FAIL 6.2s  {dim}Slow --    {red, bold}FAILED   {dim}7m ago


{yellow background, centered, floating over the bottom of the list}
  +------------------------------------------+
  | Cancel feat/search (d4e5f67)?   y / n    |
  +------------------------------------------+

{dim}
  j/k move   c cancel   q quit
```

**Design notes:**

- A small inline prompt, not a modal dialog. It floats at the bottom
  of the list area, over the empty space. It names the branch and
  commit so you know exactly what you're killing.
- `y` confirms, `n` (or Esc) dismisses. Two keys. No "type YES to
  confirm" ceremony -- this is a hobby CI, not a production database.
- For scheduled (not-yet-running) jobs, skip this confirmation
  entirely. Cancelling something that hasn't started is harmless.
  The confirmation is only for running jobs where a process will
  be killed.
- After confirming, the row updates in place:

```
  d4e5f67  feat/search    {green}Build 0.2s  {dim}Fast 7s  {dim}Slow --            {dim}CANCELLED {dim}12s ago
```

  The row goes dim. CANCELLED is shown without color -- it's not a
  failure, it's not a success, it's just done. It fades into the
  background of the list naturally.


---

## Empty State -- First Launch

```
{white on charcoal}
 fun-ci

{default background}



                    No runs yet.

          Trigger one:  fun-ci trigger HEAD
          Or hook it:   fun-ci install-hook pre-push


{dim}
  q quit
```

**Design notes:**

- Centered, minimal, calm. No banner, no decoration. Just the two
  commands you need to get started.
- The footer shrinks to just `q`. Nothing else makes sense yet.


---

## Animation & Color Reference

### Spinner

The braille dot spinner on RUNNING stages cycles through these
frames at approximately 100ms per frame:

    Frame 1: "
    Frame 2: "
    Frame 3: "
    Frame 4: "
    Frame 5: "
    Frame 6: "
    Frame 7: "
    Frame 8: "

This creates a smooth, circular motion that feels organic. The
spinner appears immediately before the ticking elapsed time:

    {cyan}Fast " 3s

The spinner runs only on the currently active stage of a running
pipeline. One spinner on screen at a time. It's a heartbeat -- you
can tell the system is alive from across the room.

### Live Timer

The elapsed time on the active stage increments every second:

    Fast " 3s  -->  Fast " 4s  -->  Fast " 5s

The number updates in place (no redraw flicker). Combined with
the spinner, this gives a smooth pulse to the active row.

### Colors

| Element                   | Color / Style        | Why                                |
|---------------------------|----------------------|------------------------------------|
| Header bar background     | Dark charcoal (236)  | Grounds the top of the screen      |
| Header text               | White                | Clean contrast on dark bar         |
| Streak counter            | Green, same as header| Reward, associated with passing    |
| "Streak broken"           | Default white        | Factual, not alarming              |
| Passed stage times        | Green                | Passed = green, everywhere         |
| PASSED status             | Green, bold          | The big green word you scan for    |
| Failed stage              | Red, bold            | The red that draws your eye        |
| FAILED status             | Red, bold            | Matches the stage color            |
| Timed out stage           | Yellow, bold         | Warning, not error -- different    |
| TIMED OUT status          | Yellow, bold         | Matches the stage color            |
| Running stage + spinner   | Cyan                 | Active, energetic, distinct        |
| RUNNING status            | Cyan, bold           | Matches the stage color            |
| Scheduled row             | Dim (gray)           | Not interesting yet                |
| "Scheduled..." text       | Dim, italic          | Patient, waiting                   |
| Unreached stages (`--`)   | Dim                  | Visually recedes                   |
| Relative time ("2m ago")  | Dim                  | Secondary info, always available   |
| CANCELLED status          | Dim                  | Neither good nor bad, just done    |
| Cancel prompt box         | Yellow background    | Attention without alarm            |
| Footer keys               | Dim                  | Available, not competing           |

### Terminal Requirements

- 256-color support (for the charcoal header and subtle row tints).
  Falls back gracefully to 16 colors -- bold/dim still carry meaning.
- Unicode support for the braille spinner. Falls back to ASCII
  spinner (`| / - \`) if braille characters don't render.
- Minimum 60 columns wide. Narrower terminals truncate branch names
  first, then commit hashes shorten to 5 chars.

### Refresh Behavior

- Auto-refresh every 1 second when any row is RUNNING (for the
  spinner and live timer).
- Auto-refresh every 5 seconds when everything is settled (to pick
  up new runs from triggers).
- Manual `r` is NOT offered. The board is always live. Adding a
  manual refresh key implies the data might be stale, which
  undermines trust. If the data is always fresh, the user never
  needs to wonder.
- The refresh is surgical: only changed rows re-render. No full
  screen redraw, no flicker.


---

## Keyboard Summary

Three keys. That's it.

| Key      | Action                                                    |
|----------|-----------------------------------------------------------|
| j / Down | Move cursor down (cursor is invisible until first press)  |
| k / Up   | Move cursor up                                            |
| c        | Cancel selected job (confirms for running, instant for scheduled) |
| q        | Quit immediately                                          |

No `Enter` key to drill down -- there is no drill-down. No `?` for
help -- three keys don't need a help screen. No `r` for refresh --
the board is always live.

The cursor is **invisible by default**. The board is a status display
first. When you press `j` or `k`, the cursor appears (as a `>` marker
or row highlight). This means the default experience is pure glancing
-- no cursor, no selection, just a board. You only enter "interactive
mode" when you want to cancel something.


---

## Open Questions

1. **TIMED OUT as a display state**: The spec's state machine has
   four states (Scheduled, Running, Completed, Failed) but the
   failure modes table uses TimedOut. The wireframe renders timeouts
   in yellow vs failures in red. This feels important enough to
   formalize in the state machine. Recommendation: add TimedOut.

2. **Cancelled state**: The spec's failure modes table mentions
   Cancelled for orphaned/superseded jobs. The wireframe shows
   CANCELLED as a dim, neutral state. This also needs to be in the
   state machine. Recommendation: add Cancelled.

3. **Row limit**: How many rows to show? The wireframe shows ~7.
   Suggestion: fill the terminal height minus 3 lines (header +
   footer + 1 blank). On a standard 24-line terminal, that's ~20
   rows. Older runs scroll off the bottom naturally. No pagination,
   no scrolling -- if it scrolled off, it's old news.
