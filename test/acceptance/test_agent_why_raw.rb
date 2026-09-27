# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "agent_client"
require "json"

# A failed stage's output is kept as a window, and `why --raw` prints it
# (acceptance-tests.md, AT-10.6): its first 1 MB up to a line end, a marker
# saying how many bytes were dropped, and its last 7 MB from a line start.
class TestAgentWhyRaw < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  LINE = "#{"x" * 99}\n".freeze
  # After "first\n", 10,485 whole lines fit in the first 1,048,576 bytes; the
  # last 7,340,032 bytes start mid-line, and 73,400 whole lines follow.
  HEAD = "first\n#{LINE * 10_485}".freeze
  TAIL = "#{LINE * 73_400}last\n".freeze
  OUTPUT = "first\n#{LINE * 90_000}last\n".freeze

  def setup
    @pipeline = TriggerCliClient.open(command_runner: fast_suite_printing(OUTPUT))
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    @pipeline.trigger(commit_hash: SHA, branch: "main")
  end

  def teardown = @pipeline.close

  def test_should_print_the_first_megabyte_up_to_a_line_end
    @agent.why("--raw")

    assert @agent.stdout.start_with?("#{HEAD}[fun-ci:")
  end

  def test_should_say_how_many_bytes_were_dropped
    @agent.why("--raw")

    assert_includes @agent.stdout, "\n[fun-ci: 611500 bytes dropped here]\n"
  end

  def test_should_print_the_last_seven_megabytes_from_a_line_start
    @agent.why("--raw")

    assert @agent.stdout.end_with?("bytes dropped here]\n#{TAIL}")
  end

  def test_should_name_the_raw_command_in_why
    @agent.why

    assert_includes @agent.stdout.lines, "The whole output: fun-ci why 3f9c2ab fast --raw\n"
  end

  private

  def fast_suite_printing(output)
    ->(cmd) { cmd.include?("fast.sh") ? [output, FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)] }
  end
end
