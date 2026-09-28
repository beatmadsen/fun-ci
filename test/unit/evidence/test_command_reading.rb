# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/evidence/command_reading"

# A project's command's stdout, read up to a limit; past it, the command is
# stopped (architecture.md, "Evidence of a failed stage").
class TestCommandReading < Minitest::Test
  LIMIT = 1000

  def setup
    @reader, @writer = IO.pipe
    @stops = []
  end

  def teardown = [@reader, @writer].each(&:close)

  def test_should_let_a_command_print_exactly_its_limit
    read("x" * LIMIT)

    assert_empty @stops
  end

  def test_should_stop_a_command_that_prints_past_its_limit
    read("x" * (LIMIT + 1))

    assert_equal [:stopped], @stops
  end

  def test_should_answer_all_it_read
    assert_equal "one\ntwo\n", read("one\ntwo\n")
  end

  private

  # Writes `printed` and closes the write end, so reading ends where it does.
  def read(printed)
    reading = FunCi::Evidence::CommandReading.start(@reader, LIMIT, -> { @stops << :stopped })
    @writer.write(printed)
    @writer.close
    reading.finish(5)
  end
end
