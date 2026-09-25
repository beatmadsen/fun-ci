# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/console/stage_change_detector"

module StageChangeDetectorFixtures
  private

  def detect(previous, current)
    FunCi::Console::StageChangeDetector.detect(previous, current)
  end

  def make_run(id, **statuses)
    { id: id, stages: statuses.map { |name, status| { stage: name.to_s, status: status } } }
  end
end

class TestStageChangeDetectorNoChanges < Minitest::Test
  include StageChangeDetectorFixtures

  def test_should_return_empty_when_previous_runs_empty
    assert_equal [], detect([], [make_run(1, lint: "running")])
  end

  def test_should_return_empty_when_stages_unchanged
    runs = [make_run(1, lint: "running")]
    assert_equal [], detect(runs, runs)
  end

  def test_should_return_empty_when_run_disappears_from_current
    assert_equal [], detect([make_run(1, lint: "running")], [])
  end
end

class TestStageChangeDetectorTransitions < Minitest::Test
  include StageChangeDetectorFixtures

  def test_should_detect_stage_completing
    changes = detect([make_run(1, lint: "running")], [make_run(1, lint: "completed")])
    assert_equal 1, changes.length
    assert_equal "lint", changes[0].stage
    assert_equal "running", changes[0].from
    assert_equal "completed", changes[0].to
    assert_equal 1, changes[0].run_id
  end

  def test_should_detect_stage_failing
    changes = detect([make_run(1, build: "running")], [make_run(1, build: "failed")])
    assert_equal 1, changes.length
    assert_equal "failed", changes[0].to
  end

  def test_should_detect_stage_timing_out
    changes = detect([make_run(1, slow: "running")], [make_run(1, slow: "timed_out")])
    assert_equal 1, changes.length
    assert_equal "timed_out", changes[0].to
  end

  def test_should_detect_new_stage_appearing
    previous = [make_run(1, lint: "completed")]
    changes = detect(previous, [make_run(1, lint: "completed", fast: "running")])
    assert_equal 1, changes.length
    assert_equal "fast", changes[0].stage
    assert_nil changes[0].from
    assert_equal "running", changes[0].to
  end

  def test_should_detect_multiple_changes_in_same_run
    previous = [make_run(1, lint: "running", build: "running")]
    changes = detect(previous, [make_run(1, lint: "completed", build: "failed")])
    assert_equal 2, changes.length
    assert_equal %w[build lint], changes.map(&:stage).sort
  end

  def test_should_detect_changes_across_multiple_runs
    previous = [make_run(1, lint: "running"), make_run(2, build: "running")]
    current = [make_run(1, lint: "completed"), make_run(2, build: "failed")]
    changes = detect(previous, current)
    assert_equal 2, changes.length
    assert_equal [1, 2], changes.map(&:run_id).sort
  end
end

class TestStageChangeDetectorChangeValue < Minitest::Test
  def test_change_should_be_a_data_object_with_named_fields
    change = FunCi::Console::StageChangeDetector::Change.new(run_id: 42, stage: "lint", from: "running",
                                                             to: "completed")
    assert_equal 42, change.run_id
    assert_equal "lint", change.stage
    assert_equal "running", change.from
    assert_equal "completed", change.to
  end

  def test_change_should_be_frozen
    change = FunCi::Console::StageChangeDetector::Change.new(run_id: 1, stage: "lint", from: "running", to: "completed")
    assert change.frozen?
  end
end
