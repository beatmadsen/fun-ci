# frozen_string_literal: true

require_relative "../../acceptance/trigger_cli_shared"
require_relative "../../acceptance/agent_client"
require_relative "../../support/process_deadline"
require "json"

# A project's own command is an extractor (acceptance-tests.md, AT-10.15):
# the stages are stand-ins, the command in the project is real. How its
# output is read and how it is killed with what it started belong to
# CommandOutput and CommandRunner, and are pinned there.
class TestWhyRunExtractor < Minitest::Test
  include ProcessDeadline

  SHA = "3f9c2ab0c4d1e2f3a4b5c6d7e8f901234567890a"
  REPORTER = <<~SH
    #!/bin/sh
    stage=$(grep -o '"stage":"[a-z]*"' | cut -d'"' -f4)
    echo '{"schema": 1, "facts": [{"name": "stage seen", "value": "'"$stage"'"}]}'
  SH
  STUCK = <<~SH
    #!/bin/sh
    exec sleep 30
  SH

  def teardown = @pipeline.close

  def test_should_give_the_command_the_context_on_stdin
    run_with_extractor(REPORTER)

    assert_includes evidence["facts"], { "name" => "stage seen", "value" => "fast", "extractor" => "run:sh .fun-ci/x" }
  end

  def test_should_record_a_command_still_running_at_the_end_of_the_budget_as_a_problem
    run_with_extractor(STUCK, budget: "0.3")

    assert_match(/killed/, evidence["problems"].first["message"])
  end

  def test_should_leave_the_stage_s_verdict_as_it_was
    run_with_extractor(STUCK, budget: "0.3")

    assert_equal 1, @agent.why
  end

  private

  def run_with_extractor(script, budget: "2")
    @pipeline = TriggerCliClient.open(command_runner: lambda { |cmd|
      cmd.include?("fast.sh") ? ["boom\n", FakeStatus.new(false, 1)] : ["", FakeStatus.new(true, 0)]
    })
    @agent = AgentClient.new(@pipeline.workspace)
    @agent.git.commit(SHA, "Add retry to fetch")
    write_extractor(script)
    within_deadline { @pipeline.trigger(commit_hash: SHA, branch: "main", config: config(budget)) }
  end

  def write_extractor(script)
    FileUtils.mkdir_p(File.join(@pipeline.project_dir, ".fun-ci"))
    File.write(File.join(@pipeline.project_dir, ".fun-ci", "x"), script)
    File.chmod(0o755, File.join(@pipeline.project_dir, ".fun-ci", "x"))
  end

  def config(budget)
    "evidence:\n  budget: #{budget}\n  stages:\n    fast:\n      - run: sh .fun-ci/x\n        format: json\n"
  end

  def evidence
    @agent.why("--json")
    JSON.parse(@agent.stdout)["evidence"]
  end
end
