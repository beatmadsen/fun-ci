# frozen_string_literal: true

require_relative "../../test_helper"
require "tmpdir"
require "fun_ci/pipeline/trigger_params"
require_relative "../../support/process_deadline"

# The executor a stage runs through, with no runner injected: a real process.
class TestCommandExecutorProcess < Minitest::Test
  include ProcessDeadline

  def test_the_executor_runs_the_command_in_the_directory_it_was_made_for
    dir = File.realpath(Dir.tmpdir)
    output, = within_deadline { FunCi::Pipeline::Seams.new.executor(dir).call("pwd -P", 30) }

    assert_equal "#{dir}\n", output
  end
end
