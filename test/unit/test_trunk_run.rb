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
    def notice(pending) = "fun-ci: fetching for #{pending}"

    def recheck(heads, tip)
      heads.keys.map { |commit| FunCi::Trunk::Check.new(commit: commit, tip: tip, merge: CLEAN) }
    end
  end

  # A trunk whose check raises in the thread.
  class RaisingTrunk
    def start(sha, _fetches) = sha
    def notice(_pending) = nil
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
    def trunk_heads(except:) = except && { "bbb2222" => "old" }
    def trunk_check_started = @calls << [:started]
    def trunk_fetch_process(pid) = @calls << [:process, pid]
    def trunk_fetched(fetched, tip) = @calls << [:fetched, fetched, tip&.sha]
    def trunk_checked(check) = @calls << [:checked, check.merge, check.commit]
  end

  def test_should_note_the_check_has_begun_before_recording_it
    assert_equal [:started], run_with(FakeTrunk.new(CLEAN)).calls.first
  end

  def test_should_record_the_check_the_trunk_made
    assert_equal [:checked, CLEAN, "abc1234"], run_with(FakeTrunk.new(CLEAN)).calls[1]
  end

  def test_should_record_a_check_that_raised_as_unknown_with_its_reason
    assert_equal [:checked, FunCi::Trunk::Merge.unknown("the check failed: git went away"), "abc1234"],
                 run_with(RaisingTrunk.new).calls.last
  end

  def test_should_record_a_check_that_raised_without_a_tip
    recorder = TrunkRecorder.new
    checks = []
    recorder.define_singleton_method(:trunk_checked) { |check| checks << check }
    FunCi::Pipeline::TrunkRun.start(RaisingTrunk.new, "abc1234", recorder).finish(recorder)

    assert_nil checks.first.tip
  end

  def test_should_record_a_check_that_could_not_start_as_unknown_with_its_reason
    assert_equal [[:checked, FunCi::Trunk::Merge.unknown("the check failed: no git"), "abc1234"]],
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

  def test_should_record_the_other_branches_heads_checked_against_the_new_tip
    assert_equal [:checked, CLEAN, "bbb2222"], run_with(FetchingTrunk.new).calls.last
  end

  def test_should_give_the_notice_of_a_first_fetch
    assert_equal "fun-ci: fetching for abc1234",
                 FunCi::Pipeline::TrunkRun.start(FetchingTrunk.new, "abc1234", TrunkRecorder.new).notice
  end

  def test_should_give_no_notice_when_the_project_checks_no_trunk
    assert_nil FunCi::Pipeline::TrunkRun.start(FakeTrunk::NONE, "abc1234", TrunkRecorder.new).notice
  end

  private

  def run_with(trunk)
    recorder = TrunkRecorder.new
    FunCi::Pipeline::TrunkRun.start(trunk, "abc1234", recorder).finish(recorder)
    recorder
  end
end
