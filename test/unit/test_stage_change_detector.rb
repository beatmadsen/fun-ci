# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/tui/stage_change_detector"

class TestStageChangeDetectorNoChanges < Minitest::Test
  def test_should_return_empty_when_previous_runs_empty
    current = [make_run(1, [make_stage("lint", "running")])]
    changes = FunCi::Tui::StageChangeDetector.detect([], current)
    assert_equal [], changes
  end

  def test_should_return_empty_when_stages_unchanged
    runs = [make_run(1, [make_stage("lint", "running")])]
    changes = FunCi::Tui::StageChangeDetector.detect(runs, runs)
    assert_equal [], changes
  end

  def test_should_return_empty_when_run_disappears_from_current
    previous = [make_run(1, [make_stage("lint", "running")])]
    changes = FunCi::Tui::StageChangeDetector.detect(previous, [])
    assert_equal [], changes
  end

  private

  def make_run(id, stages)
    { id: id, stages: stages }
  end

  def make_stage(name, status)
    { stage: name, status: status }
  end
end

class TestStageChangeDetectorTransitions < Minitest::Test
  def test_should_detect_stage_completing
    previous = [make_run(1, [make_stage("lint", "running")])]
    current  = [make_run(1, [make_stage("lint", "completed")])]
    changes = FunCi::Tui::StageChangeDetector.detect(previous, current)
    assert_equal 1, changes.length
    assert_equal "lint", changes[0].stage
    assert_equal "running", changes[0].from
    assert_equal "completed", changes[0].to
    assert_equal 1, changes[0].run_id
  end

  def test_should_detect_stage_failing
    previous = [make_run(1, [make_stage("build", "running")])]
    current  = [make_run(1, [make_stage("build", "failed")])]
    changes = FunCi::Tui::StageChangeDetector.detect(previous, current)
    assert_equal 1, changes.length
    assert_equal "failed", changes[0].to
  end

  def test_should_detect_stage_timing_out
    previous = [make_run(1, [make_stage("slow", "running")])]
    current  = [make_run(1, [make_stage("slow", "timed_out")])]
    changes = FunCi::Tui::StageChangeDetector.detect(previous, current)
    assert_equal 1, changes.length
    assert_equal "timed_out", changes[0].to
  end

  def test_should_detect_new_stage_appearing
    previous = [make_run(1, [make_stage("lint", "completed")])]
    current  = [make_run(1, [
      make_stage("lint", "completed"),
      make_stage("fast", "running")
    ])]
    changes = FunCi::Tui::StageChangeDetector.detect(previous, current)
    assert_equal 1, changes.length
    assert_equal "fast", changes[0].stage
    assert_nil changes[0].from
    assert_equal "running", changes[0].to
  end

  def test_should_detect_multiple_changes_in_same_run
    previous = [make_run(1, [
      make_stage("lint", "running"),
      make_stage("build", "running")
    ])]
    current = [make_run(1, [
      make_stage("lint", "completed"),
      make_stage("build", "failed")
    ])]
    changes = FunCi::Tui::StageChangeDetector.detect(previous, current)
    assert_equal 2, changes.length
    stages = changes.map(&:stage).sort
    assert_equal %w[build lint], stages
  end

  def test_should_detect_changes_across_multiple_runs
    previous = [
      make_run(1, [make_stage("lint", "running")]),
      make_run(2, [make_stage("build", "running")])
    ]
    current = [
      make_run(1, [make_stage("lint", "completed")]),
      make_run(2, [make_stage("build", "failed")])
    ]
    changes = FunCi::Tui::StageChangeDetector.detect(previous, current)
    assert_equal 2, changes.length
    run_ids = changes.map(&:run_id).sort
    assert_equal [1, 2], run_ids
  end

  private

  def make_run(id, stages)
    { id: id, stages: stages }
  end

  def make_stage(name, status)
    { stage: name, status: status }
  end
end

class TestStageChangeDetectorChangeValue < Minitest::Test
  def test_change_should_be_a_data_object_with_named_fields
    change = FunCi::Tui::StageChangeDetector::Change.new(
      run_id: 42, stage: "lint", from: "running", to: "completed"
    )
    assert_equal 42, change.run_id
    assert_equal "lint", change.stage
    assert_equal "running", change.from
    assert_equal "completed", change.to
  end

  def test_change_should_be_frozen
    change = FunCi::Tui::StageChangeDetector::Change.new(
      run_id: 1, stage: "lint", from: "running", to: "completed"
    )
    assert change.frozen?
  end
end
