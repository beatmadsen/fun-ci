# Background Process Result Reporting -- Design Document

## The Bug

The slow suite is fire-and-forget. `spawn_slow_suite` in `lib/fun_ci/trigger.rb` calls `Process.spawn` + `Process.detach`, sends output to `/dev/null`, and returns immediately. The trigger then calls `@recorder.complete_run` on line 80 -- marking the pipeline as "completed" before the slow suite has even started running. Nobody ever:

1. Waits for the slow process to finish
2. Checks its exit code
3. Calls `end_stage` with a result ("completed", "failed", or "timed_out")
4. Enforces the 5-minute timeout on the spawned process
5. Defers `complete_run` until the slow suite actually finishes

The TUI shows the pipeline as "completed" regardless of what the slow suite does. The slow stage job stays in "running" status forever.


## Desired Behavior (per specification.md)

The trigger returns to the developer after the fast suite. It returns exit code 0 if the fast suite passed. That part works. What must change is the background wrapper around the slow suite.

After spawn, a background wrapper process must:

- Run `slow.sh <commit>` with output captured (or at least not lost to `/dev/null` -- the spec says results are visible in TUI)
- Enforce the 5-minute (300s) time budget. Kill the process if it exceeds the budget.
- After the slow script finishes (or is killed):
  - Call `recorder.end_stage(job_id, "completed")` if exit code is 0
  - Call `recorder.end_stage(job_id, "failed")` if exit code is non-zero
  - Call `recorder.end_stage(job_id, "timed_out")` if the budget was exceeded
- After recording the stage result:
  - Call `recorder.complete_run` if the slow stage completed successfully
  - Call `recorder.fail_run` if the slow stage failed or timed out
- Clean up: no orphaned processes, no zombie PIDs, no leaked file descriptors

The foreground trigger should NOT call `complete_run` after spawning the slow suite. That responsibility moves to the background wrapper.


## High-Level Design

### Option: BackgroundWrapper (extracted class)

Extract the background wrapper into its own class, e.g. `BackgroundWrapper` or `SlowSuiteRunner`. The trigger creates it, hands it the recorder and the command, and the wrapper does the rest in a forked/spawned process.

Responsibilities of the wrapper:
- Run the command with a timeout
- Translate exit status to recorder calls
- Write/clean up the PID file
- Handle SIGTERM gracefully (for cancellation by a newer trigger)

The trigger's `run` method changes:
- After `run_stage(config, "fast")` passes, spawn the background wrapper
- Do NOT call `complete_run` from the trigger. The wrapper owns that.
- Return 0 to the developer immediately

### The recorder must be usable from the background process

The current `DbRecorder` holds a `@pipeline_run_id` and a `@db` connection. If we fork, we need to be careful:
- SQLite connections should not be shared across fork boundaries
- The wrapper will need to open its own DB connection after fork
- Alternatively, the wrapper receives the `pipeline_run_id` and `db_path` and constructs its own recorder

This is a design detail that will emerge during inner-loop TDD. The key contract is: the wrapper calls `end_stage` and `complete_run`/`fail_run` on a recorder.


## Test Strategy

### Acceptance Tests (outer loop)

These go in `test/acceptance/test_trigger_cli.rb` and use the `TriggerCliClient`. They verify the feature from the developer's perspective: "after the trigger returns, the database eventually reflects the slow suite result."

The client already has `pipeline_runs_for` and `stage_jobs_for` methods, plus unimplemented stubs for `wait_for_stage` and `background_process_alive?` that were designed for exactly this purpose.

Key acceptance tests:

1. **Slow suite pass should be recorded in the database**
   - Given: all stages pass (slow.sh exits 0)
   - When: trigger is invoked, then poll DB until slow stage has a terminal status
   - Then: slow stage_job status is "completed", pipeline_run status is "completed"

2. **Slow suite failure should be recorded in the database**
   - Given: slow.sh exits non-zero
   - When: trigger is invoked, then poll DB until slow stage has a terminal status
   - Then: slow stage_job status is "failed", pipeline_run status is "failed"

3. **Slow suite timeout should be recorded in the database**
   - Given: slow.sh runs longer than the budget (use 1s budget in test)
   - When: trigger is invoked, then poll DB until slow stage has a terminal status
   - Then: slow stage_job status is "timed_out", pipeline_run status is "failed"
   - And: the slow.sh process is no longer running (no orphan)

4. **Pipeline run should NOT be "completed" before slow suite finishes**
   - Given: slow.sh takes a moment to run (e.g. `sleep 1; exit 0` with a 10s budget)
   - When: trigger returns (exit 0)
   - Then: immediately after trigger returns, pipeline_run status is NOT "completed" yet
   - Then: after polling, pipeline_run status eventually becomes "completed"

These acceptance tests need the `TriggerCliClient` to run the trigger without a `command_runner` (so it actually spawns processes), and then poll the database for results. The `wait_for_stage` method needs to be implemented using condition polling with a timeout, not sleep. Pattern from knowledge.md:

```ruby
def wait_for_stage(stage_name, commit_hash:, timeout: 10)
  deadline = Time.now + timeout
  loop do
    runs = pipeline_runs_for(commit_hash: commit_hash)
    break if runs.empty?
    jobs = stage_jobs_for(pipeline_run_id: runs.first[:id])
    job = jobs.find { |j| j[:stage] == stage_name }
    return job if job && StageJob::TERMINAL_STATUSES.include?(job[:status])
    raise Timeout::Error, "stage #{stage_name} did not reach terminal status" if Time.now > deadline
    Thread.pass
  end
end
```

### Unit Tests (inner loop)

These drive the design of the new `BackgroundWrapper` class (or whatever name emerges). They use dependency injection -- no real process spawning, no real database, no real sleep.

**Testing the wrapper's core logic (command_runner DI):**

The wrapper should accept a `command_runner` just like `Trigger` does. In unit tests, the command_runner is a lambda that returns immediately with a fake status. This makes the tests deterministic and fast.

1. **Should call end_stage with "completed" when command exits 0**
   - Given: a fake runner that returns success, a mock/fake recorder
   - When: wrapper.run is called
   - Then: recorder received `end_stage(job_id, "completed")`

2. **Should call end_stage with "failed" when command exits non-zero**
   - Given: a fake runner that returns failure
   - When: wrapper.run is called
   - Then: recorder received `end_stage(job_id, "failed")`

3. **Should call end_stage with "timed_out" when command exceeds budget**
   - Given: a fake runner that raises Timeout::Error (or a wrapper that detects the timeout)
   - When: wrapper.run is called
   - Then: recorder received `end_stage(job_id, "timed_out")`

4. **Should call complete_run after successful slow stage**
   - Given: fake runner returns success
   - When: wrapper.run is called
   - Then: recorder received `complete_run`

5. **Should call fail_run after failed slow stage**
   - Given: fake runner returns failure
   - When: wrapper.run is called
   - Then: recorder received `fail_run`

6. **Should call fail_run after timed-out slow stage**
   - Given: fake runner raises timeout
   - When: wrapper.run is called
   - Then: recorder received `fail_run`

7. **Should clean up PID file after completion**
   - Given: a PID file path
   - When: wrapper.run completes (any outcome)
   - Then: PID file no longer exists

**Testing timeout enforcement (no real waiting):**

The wrapper uses `Timeout.timeout(budget)` around the command_runner call. In unit tests, the command_runner lambda can simulate timeout by raising `Timeout::Error`. This tests the wrapper's handling without actually waiting.

For a more integration-level timeout test (proving the real timeout mechanism works), use a 1-second budget with a command_runner that sleeps for 2 seconds. This is acceptable because it takes 1-2 seconds, not 5 minutes.

**Testing that Trigger no longer calls complete_run:**

8. **Trigger should NOT call complete_run when slow suite is spawned**
   - Given: a fake recorder that tracks calls
   - When: trigger.run completes with all stages passing
   - Then: recorder did NOT receive `complete_run`
   - (The wrapper is responsible for that now)

This test uses the existing `FakeStatus` + `command_runner` pattern from `test/unit/test_trigger.rb`. The fake recorder is a simple object that records method calls:

```ruby
class FakeRecorder
  attr_reader :calls

  def initialize
    @calls = []
  end

  def create_run(commit_hash:, branch:) = @calls << [:create_run, commit_hash, branch]
  def start_stage(stage) = (@calls << [:start_stage, stage]; "job-#{stage}")
  def end_stage(job_id, status) = @calls << [:end_stage, job_id, status]
  def complete_run = @calls << [:complete_run]
  def fail_run = @calls << [:fail_run]
end
```

### What NOT to test

- Do not test `Process.spawn`, `Process.detach`, `Process.kill` directly. Those are Ruby stdlib. Test through the command_runner DI seam.
- Do not test the recorder's database writes -- those are already covered by `test/unit/test_pipeline_run.rb` and `test/unit/test_stage_job.rb`.
- Do not test the PID file format -- that is an implementation detail. Test the observable behavior (stale pipeline cancellation already has tests).
- Do not use `instance_variable_get` or `instance_variable_set` in any test.


## Implementation Sequence (ATDD cycle order)

1. Write acceptance test: "slow suite pass should be recorded" -- it will fail because `complete_run` is called too early and `end_stage` is never called for slow.
2. Drop to unit tests. Drive out the BackgroundWrapper class with tests 1, 4, 7.
3. Wire BackgroundWrapper into Trigger. Write unit test 8 (trigger no longer calls complete_run).
4. Re-run acceptance test -- should pass for the success case.
5. Write acceptance test: "slow suite failure should be recorded" -- may already pass if the wrapper handles non-zero exit. If not, drive with unit tests 2, 5.
6. Write acceptance test: "slow suite timeout should be recorded" -- drive with unit tests 3, 6.
7. Write acceptance test: "pipeline run should NOT be completed before slow finishes" -- verifies the timing contract.
8. Refactor after each green.

One acceptance test at a time. One unit test at a time inside each acceptance cycle. Never skip the refactor step.


## Open Questions

- Should the wrapper capture slow.sh output for later display in TUI, or is it acceptable to discard it? The spec says "visible in TUI as a failed job" with "drill-down to see which tests." This implies output capture is eventually needed. For now, capturing to a log file (not `/dev/null`) would be a reasonable first step. The output storage format is a separate feature.
- Should the wrapper be a forked process or a spawned thread? Fork gives process isolation but complicates SQLite connection sharing. Thread is simpler but means a crash in the wrapper could affect the trigger process (which has already returned exit 0 to the git hook). The spec says "deeply resilient" which favors fork. This will be explored during implementation.
- The `cancel_stale_pipeline` mechanism currently kills the slow.sh process. With a wrapper in place, should it kill the wrapper instead (which then cleans up the child)? Probably yes -- the wrapper should trap SIGTERM and do orderly shutdown.
