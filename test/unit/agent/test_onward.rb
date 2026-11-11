# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/onward"

# What a wait does once the run it waited on is decided (acceptance-tests.md,
# AT-9.12, AT-9.21).
class TestOnward < Minitest::Test
  Report = Data.define(:verdict, :superseded_by)
  SUPERSEDED = Report.new(verdict: :superseded, superseded_by: "bbb2222")

  def test_should_follow_the_branch_to_the_commit_that_superseded_the_run
    assert_equal :follow, FunCi::Agent::Onward.decide(SUPERSEDED, follow_branch: true, ran_again: false)
  end

  def test_should_run_a_superseded_commit_again_when_not_following_the_branch
    assert_equal :run_again, FunCi::Agent::Onward.decide(SUPERSEDED, follow_branch: false, ran_again: false)
  end

  def test_should_run_a_superseded_commit_again_only_once
    assert_equal :stop, FunCi::Agent::Onward.decide(SUPERSEDED, follow_branch: false, ran_again: true)
  end

  # A deadline can pass on a run superseded and then decided otherwise (AT-9.21 runs only a cancelled one again).
  def test_should_not_run_again_a_commit_whose_run_was_not_cancelled
    report = Report.new(verdict: :pass, superseded_by: "bbb2222")

    assert_equal :stop, FunCi::Agent::Onward.decide(report, follow_branch: false, ran_again: false)
  end

  def test_should_stop_at_a_run_nothing_superseded
    report = Report.new(verdict: :superseded, superseded_by: nil)

    assert_equal :stop, FunCi::Agent::Onward.decide(report, follow_branch: true, ran_again: false)
  end

  def test_should_stop_when_no_run_turned_up
    assert_equal :stop, FunCi::Agent::Onward.decide(nil, follow_branch: true, ran_again: false)
  end
end
