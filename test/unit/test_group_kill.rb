# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/group_kill"

# Killing a stage's process group, and what left it. A member forking as the
# KILL arrives leaves a child in the group the signal missed (measured: under
# load a fetch's ssh outlived the kill), so the group is killed again while
# any member lives.
class TestGroupKill < Minitest::Test
  # Answers each probe of the group (signal 0) from `alive`, in turn, and
  # records every other signal.
  class Signals
    attr_reader :sent

    def initialize(alive)
      @alive = alive
      @sent = []
    end

    def call(signal, target)
      return probe if signal.is_a?(Integer)

      @sent << [signal, target]
    end

    private

    def probe
      raise Errno::ESRCH if @alive.empty?

      @alive.shift || raise(Errno::ESRCH)
    end
  end

  def test_should_send_term_then_kill_to_the_group_and_what_left_it
    signals = Signals.new([])
    FunCi::Pipeline::GroupKill.kill(300, [-320], signal: signals)

    assert_equal [["TERM", -300], ["TERM", -320], ["KILL", -300], ["KILL", -320]], signals.sent
  end

  def test_should_kill_the_group_again_while_a_member_lives
    signals = Signals.new([true])
    FunCi::Pipeline::GroupKill.kill(300, [], signal: signals)

    assert_equal [["TERM", -300], ["KILL", -300], ["KILL", -300]], signals.sent
  end

  # On macOS a group left with only zombies answers the probe with EPERM.
  def test_should_count_a_group_of_zombies_as_gone
    signals = Signals.new([])
    signals.define_singleton_method(:probe) { raise Errno::EPERM }
    FunCi::Pipeline::GroupKill.kill(300, [], signal: signals)

    assert_equal [["TERM", -300], ["KILL", -300]], signals.sent
  end

  def test_should_give_up_on_a_group_that_never_goes
    signals = Signals.new(Array.new(100, true))
    FunCi::Pipeline::GroupKill.kill(300, [], signal: signals)

    assert_equal 2 + FunCi::Pipeline::GroupKill::ROUNDS, signals.sent.size
  end
end
