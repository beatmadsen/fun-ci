# Footer Animation Slowdown Plan

## Problem

Footer animations (failure footer, success footer) play too fast to be perceivable.
They need to be slowed down by ~8x. Header animations and stage column overlays
must NOT be affected.

## How It Currently Works

- `Animation` class has a `frame` counter incremented by `advance!`, one tick per render.
- `AnimationCompositor.footer_overlay` indexes into footer frame arrays using `animation.frame`.
- `AnimationCompositor.stage_column_overlay` indexes into stage overlay arrays (particles, colors)
  using the same `animation.frame`.
- `AnimationFrames` returns pure frame data arrays: `failure_footer` (5 frames),
  `success_footer` (5 frames), `failure_particles` (7 frames), etc.
- `Animation::TYPES` defines `total_frames` per type, which controls when `finished?` is true.

Footer and stage overlays share the same `Animation` object and its `frame` counter.

## Approach: Expand Footer Frame Arrays

Repeat each footer frame 8 times in the data arrays inside `AnimationFrames`.
The `animation.frame` counter continues to increment once per tick, but the footer
data has 8x more entries, so each visual frame displays for 8 consecutive ticks.

Stage overlay arrays are untouched, so stage overlays play at original speed.

### Concrete Changes

1. **`AnimationFrames`**: Add a `FOOTER_HOLD` constant (= 8). Modify `failure_footer`
   and `success_footer` to `flat_map` each frame into 8 repeats.

2. **`Animation::TYPES`**: Increase `total_frames` for `:failure` (7 -> 40) and
   `:success` (16 -> 40) so the animation lives long enough for the expanded footer.
   Stage overlays already handle frame indices beyond their array length gracefully
   (return nil or clamp).

3. **Tests**: Update assertions that depend on exact frame counts or expiration timing.

### Why This Is Safe

- `failure_flanks` returns nil when `animation.frame >= particles.length` (7) --
  stage overlay simply stops, no visual artifact.
- `color_flash` clamps at last color -- no out-of-bounds.
- `sparkle_sweep` returns nil when sweep is done -- no visual artifact.
- Header animations are managed by `HeaderAnimationManager`, completely separate.
- The footer `frame_at` helper returns nil for out-of-range indices -- safe.

### Test Changes Needed

- `TestAnimationFramesFailure#test_failure_footer_has_5_frames` -> 40 frames
- `TestAnimationFramesSuccess#test_success_footer_has_5_frames` -> 40 frames
- `TestAnimationFramesFailure#test_failure_footer_first_and_last_are_nil` -> last at index 39
- `TestAnimationFramesCounts#test_failure_has_7_frames` -> 40 frames
- `TestAnimationFramesCounts#test_success_has_16_frames` -> 40 frames
- Footer content assertions: adjust frame index to account for 8x hold
  (e.g., frame 1 content now at frame 8)
- Renderer expiration tests: increase iteration budget
