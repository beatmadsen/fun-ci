# frozen_string_literal: true

require_relative "../test_helper"
require "json"
require_relative "agent_client"

# `fun-ci status --json` gives a program the facts `status` prints
# (acceptance-tests.md, AT-9.3).
class TestAgentStatusJson < Minitest::Test
  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"

  def setup
    @client = AgentClient.open
    @client.git.commit(SHA, "Add retry to fetch")
  end

  def teardown = @client.close

  def test_should_describe_the_commit_the_level_and_the_verdict
    @client.record_run(SHA, stages: { "lint" => "completed", "build" => "failed" })

    @client.status("--json")

    assert_equal({ "schema" => 1, "commit" => { "sha" => SHA, "branch" => "main", "subject" => "Add retry to fetch" },
                   "need" => "fast", "verdict" => "failed", "superseded_by" => nil },
                 document.except("stages"))
  end

  def test_should_give_each_stage_its_state
    @client.record_run(SHA, stages: { "lint" => "completed", "build" => "running" })

    @client.status("--json")

    assert_equal(%w[passed running waiting waiting], document["stages"].map { |stage| stage["state"] })
  end

  def test_should_exit_with_the_verdict_as_without_json
    @client.record_run(SHA, stages: { "lint" => "completed", "build" => "timed_out" })

    assert_equal 2, @client.status("--json")
  end

  def test_should_say_there_is_no_run_as_a_document
    @client.status("--json")

    assert_equal({ "schema" => 1, "commit" => { "sha" => SHA }, "verdict" => "unknown" }, document)
  end

  private

  def document = JSON.parse(@client.stdout)
end
