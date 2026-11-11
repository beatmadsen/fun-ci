# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/null_recorder"

# What a pipeline that records nothing answers, as when it has no database.
class TestNullRecorder < Minitest::Test
  def test_should_let_a_slow_suite_start_once_its_turn_comes
    assert FunCi::Persistence::NullRecorder.new.started_in_turn?(1)
  end
end
