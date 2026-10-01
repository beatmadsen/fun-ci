# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/probe_suite"

# A wait on a process that outlasts its deadline fails the test, naming what
# was still running, so a hang in a run nobody watched can be told from a
# slow machine afterwards. The mutation lane's short deadline keeps it quick.
class TestProcessDeadline < Minitest::Test
  PREAMBLE = 'require "support/process_deadline"; Minitest::Test.include(ProcessDeadline)'
  HANG = <<~RUBY
    reader, writer = IO.pipe
    Process.spawn("sh", "-c", "exec sleep 3600", out: writer)
    writer.close
    within_deadline { reader.read }
  RUBY

  def test_should_name_the_process_still_running_when_a_wait_runs_out
    output, = ProbeSuite.capture(HANG, preamble: PREAMBLE, env: { "MUTATION_TESTING" => "1" })

    assert_match(/still waiting on a process after 5 s; running: \d+ .*sleep 3600/, output)
  end
end
