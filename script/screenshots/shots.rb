# frozen_string_literal: true

require_relative "scenario"

module Screenshots
  # A picture for the README: the frames of a scenario to keep, one for a
  # still, several (evenly spaced) for an animation.
  Shot = Data.define(:name, :scenario, :frames)

  # The README's pictures. Each scene is pinned, so the pictures come out the
  # same every time and a changed picture means the renderer draws differently.
  module Shots
    HISTORY = [
      Run.of(11, "feature/search", "lint:0.5 build:1.4 fast:2.3 slow:51", ago: 1500),
      Run.of(10, "main", "lint:0.4 build:1.3 fast:2.0 slow:49", ago: 3600),
      Run.of(9, "fix/login", "lint:0.4 build:1.2 fast:fail@2.8 slow:47", ago: 7300)
    ].freeze
    # A run going from start to pass: its stages, the stage that just passed,
    # the milestone that makes and its scene, and how many frames to show.
    STEPS = [
      ["lint:running build:running fast:pending slow:pending", nil, nil, nil, 20],
      ["lint:0.4 build:running fast:pending slow:pending", "lint", "lint_passed", "level", 28],
      ["lint:0.4 build:1.3 fast:running slow:running", "build", "build_passed", "anvil", 30],
      ["lint:0.4 build:1.3 fast:2.1 slow:running", "fast", "fast_passed", "warp", 38],
      ["lint:0.4 build:1.3 fast:2.1 slow:48", "slow", "run_passed", "success", 60]
    ].freeze
    LINT = "lint:0.4 build:running fast:pending slow:pending"
    BUILD = "lint:0.4 build:1.3 fast:running slow:running"
    FAST = "lint:0.4 build:1.3 fast:2.1 slow:running"
    PASSED = "lint:0.4 build:1.3 fast:2.1 slow:48"
    FAILED = "lint:0.4 build:1.3 fast:fail@2.8 slow:running"
    ENDED_FAILED = "lint:0.4 build:1.3 fast:fail@2.8 slow:47"
    # name => the run's stages, the frame to keep, and the milestone and scene
    # that play (none for the header at rest).
    STILLS = {
      "lint-sweep" => [LINT, 12, %w[lint_passed sweep]],
      "build-gears" => [BUILD, 16, %w[build_passed gears]],
      "fast-yay" => [FAST, 22, %w[fast_passed yay]],
      "run-sunrise" => [PASSED, 36, %w[run_passed sunrise]],
      "rest-passed" => [PASSED, 10, nil],
      "rest-failed" => [ENDED_FAILED, 10, nil]
    }.freeze
    # name => the latest run's stages and the quiet scene; the run ended long
    # enough ago for the header to have gone quiet.
    QUIET = {
      "quiet-fireplace" => [PASSED, "fireplace"],
      "quiet-island" => [ENDED_FAILED, "island"]
    }.freeze

    def self.all
      stills = STILLS.map { |name, spec| still(name, spec) }
      [console, failure, *stills, *QUIET.map { |name, spec| quiet(name, spec) }]
    end

    def self.console
      scenario = Scenario.new(cols: 100, rows: 24)
      STEPS.each { |step| step(scenario, step) }
      Shot.new("console", scenario, (1..scenario.frames).step(2).to_a)
    end

    def self.step(scenario, step)
      words, stage, milestone, scene, ticks = step
      run = Run.of(12, "main", words)
      scenario.board([run, *HISTORY], streak: run.status == "passed" ? 3 : 2)
      scenario.event("stage_passed", run_id: 12, stage:).event(milestone, run_id: 12, animation: scene) if stage
      scenario.ticks(ticks)
    end

    def self.failure
      run = Run.of(12, "main", FAILED)
      scenario = Scenario.new(cols: 100, rows: 24).board([run, *HISTORY], streak: 0)
      scenario.event("stage_failed", run_id: 12, stage: "fast").event("run_failed", run_id: 12, animation: "explosion")
      Shot.new("failure", scenario.ticks(10), [10])
    end

    def self.still(name, (words, frame, pin), ago: 30)
      run = Run.of(12, "main", words, ago:)
      scenario = Scenario.new(cols: 100, rows: 18).board([run], streak: run.status == "failed" ? 0 : 3)
      scenario.event(pin.first, run_id: 12, animation: pin.last) if pin
      Shot.new(name, scenario.ticks(frame), [frame])
    end

    def self.quiet(name, (words, scene))
      still(name, [words, 30, ["pin", scene]], ago: 900)
    end
  end
end
