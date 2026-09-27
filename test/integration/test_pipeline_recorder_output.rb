# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/db_recorder_setup"
require "json"

# The recorder keeps the end of a failed stage's output, and a new run of a
# project drops what its runs beyond the newest 50 kept (AT-9.5).
class TestPipelineRecorderOutput < Minitest::Test
  include DbRecorderTestSetup

  def test_should_keep_the_tail_of_a_stage_s_output
    create_run
    job_id = @recorder.start_stage("fast")
    @recorder.keep_output(job_id, "\e[31mboom\e[0m\n")

    assert_equal "boom\n", job(job_id)[:output_tail]
  end

  def test_should_drop_kept_output_beyond_the_project_s_newest_50_runs_when_a_run_starts
    first_job = failed_run_in("/project")
    50.times { @recorder.create_run(commit_hash: "abc1234", branch: "main", project_path: "/project") }

    assert_nil job(first_job)[:output_tail]
  end

  def test_should_keep_output_within_the_project_s_newest_50_runs
    first_job = failed_run_in("/project")
    49.times { @recorder.create_run(commit_hash: "abc1234", branch: "main", project_path: "/project") }

    assert_equal "boom\n", job(first_job)[:output_tail]
  end

  def test_should_keep_the_failures_a_stage_reported
    create_run
    job_id = @recorder.start_stage("fast")
    @recorder.keep_failures(job_id, [{ file: "a.rb", line: 3, test: "t", message: "m" }])

    assert_equal [{ "file" => "a.rb", "line" => 3, "test" => "t", "message" => "m" }],
                 JSON.parse(job(job_id)[:failures])
  end

  def test_should_keep_no_failures_when_a_stage_reported_none
    create_run
    job_id = @recorder.start_stage("fast")
    @recorder.keep_failures(job_id, [])

    assert_nil job(job_id)[:failures]
  end

  private

  def failed_run_in(project)
    @recorder.create_run(commit_hash: "abc1234", branch: "main", project_path: project)
    @recorder.start_stage("fast").tap { |job_id| @recorder.keep_output(job_id, "boom\n") }
  end
end
