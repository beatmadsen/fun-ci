# frozen_string_literal: true

require_relative "../test_helper"
require_relative "agent_client"

# Without a stage named, `fun-ci why` takes the one the verdict does
# (acceptance-tests.md, AT-10.1): the first needed stage to fail or overrun,
# in the order they finished.
class TestAgentWhyStageChoice < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"

  def setup
    @client = AgentClient.open
    @client.git.commit(SHA, "Add retry to fetch")
  end

  def teardown = @client.close

  def test_should_take_the_needed_stage_that_failed_first
    @client.record_run(SHA, stages: { "build" => "failed", "lint" => "timed_out" })

    @client.why

    assert_match(/\Abuild failed\b/, @client.stdout.lines[1])
  end

  def test_should_take_a_stage_the_level_needs
    @client.record_run(SHA, stages: { "lint" => "completed", "build" => "completed", "fast" => "completed",
                                      "slow" => "failed" })

    @client.why("--need", "all")

    assert_match(/\Aslow failed\b/, @client.stdout.lines[1])
  end

  def test_should_say_so_when_no_needed_stage_failed
    @client.record_run(SHA, stages: { "lint" => "completed", "build" => "running" })

    @client.why

    assert_equal "No stage it needs failed or ran over budget; name one to see it: fun-ci why REV STAGE",
                 @client.stdout.lines[1].chomp
  end

  def test_should_say_so_when_no_raw_output_is_kept
    @client.record_run(SHA, stages: { "lint" => "failed" })

    @client.why("--raw")

    assert_equal "fun-ci why: no raw output is kept for lint of 3f9c2ab\n", @client.stdout
  end
end
