# frozen_string_literal: true

require_relative "trigger_cli_shared"

# A mistake in .fun-ci/config never stops a pipeline: the setting takes its
# default, the trigger names the mistake, and the commit gets its run, so
# `wait` has a verdict for the push to wait on rather than no run.
class TestTriggerConfigMistake < Minitest::Test
  UNREADABLE = "worktree_slots: 2\nsince: 2026-10-01\n"
  NAMED = "fun-ci: .fun-ci/config can't be read: Tried to load unspecified class: Date " \
          "(quote a value such as a date to read it as text)\n"

  def setup
    @client = TriggerCliClient.open(command_runner: INSTANT_SUCCESS_RUNNER)
  end

  def teardown
    @client.close
  end

  def test_should_record_a_run_when_a_setting_is_wrong
    @client.trigger(commit_hash: "abc1234", branch: "main", config: "worktree_slots: 0\n")

    assert_equal 1, @client.pipeline_runs_for(commit_hash: "abc1234").size
  end

  def test_should_record_a_run_when_the_config_cannot_be_read
    @client.trigger(commit_hash: "abc1234", branch: "main", config: UNREADABLE)

    assert_equal 1, @client.pipeline_runs_for(commit_hash: "abc1234").size
  end

  def test_should_name_the_mistake_in_the_config_while_running
    @client.trigger(commit_hash: "abc1234", branch: "main", config: UNREADABLE)

    assert_includes @client.stdout, NAMED
  end

  # The post-commit hook's run prints nowhere, so the hook names the mistake.
  def test_should_name_the_mistake_in_the_config_when_the_run_goes_to_the_background
    FileUtils.mkdir_p(File.join(@client.project_dir, ".fun-ci"))
    File.write(File.join(@client.project_dir, ".fun-ci", "config"), UNREADABLE)

    assert_includes trigger_in_background, NAMED
  end

  private

  def trigger_in_background
    stdout = StringIO.new
    forked = ->(**) { FunCi::Pipeline::PipelineForker::Forked.new(notice: nil) }
    FunCi::Pipeline::TriggerCommand.new(io: FunCi::Pipeline::Io.new(stdout: stdout, stderr: StringIO.new),
                                        recorder: FakeRecorder.new, pipeline_forker: forked,
                                        project: @client.project_dir).run(%w[--background abc1234 main])
    stdout.string
  end
end
