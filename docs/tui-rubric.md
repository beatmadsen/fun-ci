# Console rubric

What an evaluator judges the console's renders against, and how it reports
what it finds. It is drawn from the two goals in [`design.md`](design.md):
all is well, or it isn't, at a glance; and it is fun. How a pass uses it is in
[`architecture.md`](architecture.md), Polishing the console with agents.

The evaluator gets ordered PNG frames, the contact sheet, `stats.json` and this
file, never the code or the diff, and never edits.

## State feedback

What reports a state must read from the corner of the eye. These weigh most.

1. **The verdict at a glance.** From the whole screen, without reading a
   word, can you tell whether the newest run of each branch passed, failed,
   timed out or is still going? Colour and shape carry it, not text.
2. **Where the action is.** A running stage draws the eye first; then a
   failure; then a conflict with the trunk. Nothing else competes with them.
3. **Nothing drowns.** What is old, cancelled, superseded or merely
   identifying (SHA, project, age) recedes. A screen of routine rows still
   lets the one row that needs attention stand out.
4. **The same thing is in the same place.** A stage, the outcome and the
   age sit in the same column on every row, so the eye scans down a column
   rather than reading along each row.
5. **Nothing is lost.** No row wraps or runs past the edge; no run is pushed
   off screen; what is cut to fit is the least important, and a cut shows it
   was cut.
6. **Each state looks like one state.** Passed, failed, timed out, running,
   scheduled, cancelled and conflicting are each unmistakable, and a timeout
   never reads as a failure.

## Craft

7. **Hierarchy and rhythm.** Clear levels of emphasis, consistent spacing,
   alignment that holds at 60, 80, 120 and 200 columns.
8. **Palette.** Restrained, deliberate colour that belongs with the header's
   painted scenes; no colour used for two meanings; enough contrast on a
   black background.
9. **Selection and prompts.** The row under the cursor is obvious without
   hiding its state; the footer's keys and notes are there when looked for.

## Fun

10. **It is a pleasure to watch.** Decoration is welcome where it never hides
    a status (goal 2), and it fits the header's look.

## Findings

One finding per item: the scenario, the frame range, the region (rows,
columns or the element), what is wrong, which rubric number it breaks, and an
impact from 1 (polish) to 5 (a state is misread or lost). A finding of impact
3 or more is worth a pass. Say what you would expect to see instead, not how to
code it.
