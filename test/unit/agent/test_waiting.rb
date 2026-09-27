# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/waiting"
require_relative "../../support/fake_clock"

class TestWaiting < Minitest::Test
  Answer = Data.define(:verdict)
  UNDECIDED = Answer.new(:undecided)

  def setup = @clock = FakeClock.new(now: Time.utc(2026, 9, 27, 12))

  def test_should_answer_the_first_decided_report
    assert_equal :failed, waiting(UNDECIDED, UNDECIDED, Answer.new(:failed)).until_decided.verdict
  end

  def test_should_pause_a_second_between_polls
    waiting(UNDECIDED, UNDECIDED, Answer.new(:passed)).until_decided

    assert_equal [2, Time.utc(2026, 9, 27, 12, 0, 2)], [@clock.pauses, @clock.now]
  end

  def test_should_not_pause_for_a_report_already_decided
    waiting(Answer.new(:passed)).until_decided

    assert_equal 0, @clock.pauses
  end

  def test_should_keep_polling_while_there_is_no_report_yet
    assert_equal :passed, waiting(nil, nil, Answer.new(:passed)).until_decided.verdict
  end

  def test_should_give_up_with_what_it_has_at_the_deadline
    answer = waiting(*[UNDECIDED] * 10, within: 3).until_decided

    assert_equal [:undecided, 3], [answer.verdict, @clock.pauses]
  end

  private

  def waiting(*answers, within: nil)
    FunCi::Agent::Waiting.new(@clock, deadline: within && (@clock.now + within)) do
      raise "polled past the answers" if answers.empty?

      answers.shift
    end
  end
end
