# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/fake_trunk"
require "fun_ci/pipeline/trunk_run"

# A run's check against the trunk, made beside its stages and recorded after them.
class TestTrunkRun < Minitest::Test
  CLEAN = FunCi::Trunk::Merge.clean(ahead: 1, behind: 2)

  class RaisingTrunk
    def check(_sha) = raise(IOError, "git went away")
  end

  class CheckRecorder
    attr_reader :checks

    def initialize = @checks = []
    def trunk_checked(check) = @checks << check
  end

  def test_should_record_the_check_the_trunk_made
    recorder = CheckRecorder.new
    FunCi::Pipeline::TrunkRun.start(FakeTrunk.new(CLEAN), "abc1234").finish(recorder)

    assert_equal [CLEAN], recorder.checks.map(&:merge)
  end

  def test_should_record_a_check_that_raised_as_unknown_with_its_reason
    recorder = CheckRecorder.new
    FunCi::Pipeline::TrunkRun.start(RaisingTrunk.new, "abc1234").finish(recorder)

    assert_equal [FunCi::Trunk::Merge.unknown("the check failed: git went away")], recorder.checks.map(&:merge)
  end

  def test_should_record_nothing_without_a_trunk_to_check
    recorder = CheckRecorder.new
    FunCi::Pipeline::TrunkRun.start(nil, "abc1234").finish(recorder)

    assert_empty recorder.checks
  end
end
