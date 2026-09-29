# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/fake_trunk"
require "fun_ci/pipeline/trunk_run"

# A run's check against the trunk, begun before its stages, finished beside
# them, and recorded after them.
class TestTrunkRun < Minitest::Test
  CLEAN = FunCi::Trunk::Merge.clean(ahead: 1, behind: 2)
  RESULT = FunCi::Trunk::Checker::Result
  FETCHED = FunCi::Trunk::Fetched.new(error: nil)

  # Fetches a trunk as pid 4242, and finds it clean.
  class FetchingTrunk
    include TrunkKit

    def start(sha, _fetches)
      yield 4242
      sha
    end

    def finish(sha) = RESULT.new(check: trunk_check(sha, CLEAN, seen_at: Time.now), fetched: FETCHED)
  end

  # A trunk whose check raises in the thread.
  class RaisingTrunk
    def start(sha, _fetches) = sha
    def finish(_sha) = raise(IOError, "git went away")
  end

  # A trunk that can't even begin its check.
  class BrokenTrunk
    def start(_sha, _fetches) = raise(IOError, "no git")
  end

  # Remembers what the run recorded about the trunk.
  class TrunkRecorder
    attr_reader :calls

    def initialize = @calls = []
    def trunk_fetches = :fetches
    def trunk_check_started = @calls << [:started]
    def trunk_fetch_process(pid) = @calls << [:process, pid]
    def trunk_fetched(fetched, tip) = @calls << [:fetched, fetched, tip&.sha]
    def trunk_checked(check) = @calls << [:checked, check.merge]
  end

  def test_should_note_the_check_has_begun_before_recording_it
    assert_equal [:started], run_with(FakeTrunk.new(CLEAN)).calls.first
  end

  def test_should_record_the_check_the_trunk_made
    assert_equal [:checked, CLEAN], run_with(FakeTrunk.new(CLEAN)).calls.last
  end

  def test_should_record_a_check_that_raised_as_unknown_with_its_reason
    assert_equal [:checked, FunCi::Trunk::Merge.unknown("the check failed: git went away")],
                 run_with(RaisingTrunk.new).calls.last
  end

  def test_should_record_a_check_that_could_not_start_as_unknown_with_its_reason
    assert_equal [[:checked, FunCi::Trunk::Merge.unknown("the check failed: no git")]],
                 run_with(BrokenTrunk.new).calls
  end

  def test_should_record_nothing_when_the_project_checks_no_trunk
    assert_empty run_with(FakeTrunk::NONE).calls
  end

  def test_should_record_the_fetch_s_process_as_it_starts
    assert_equal [:process, 4242], run_with(FetchingTrunk.new).calls.first
  end

  def test_should_record_how_the_fetch_went_and_the_tip_it_found
    assert_equal [:fetched, FETCHED, TrunkKit::TRUNK_SHA], run_with(FetchingTrunk.new).calls[2]
  end

  private

  def run_with(trunk)
    recorder = TrunkRecorder.new
    FunCi::Pipeline::TrunkRun.start(trunk, "abc1234", recorder).finish(recorder)
    recorder
  end
end
