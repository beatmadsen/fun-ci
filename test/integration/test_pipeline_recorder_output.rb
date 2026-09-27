# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/db_recorder_setup"
require "fun_ci/evidence/document"

# A new run of a project drops what its runs beyond the newest 50 kept
# (AT-9.5, AT-10.3).
class TestPipelineRecorderOutput < Minitest::Test
  include DbRecorderTestSetup

  def test_should_drop_kept_output_beyond_the_project_s_newest_50_runs_when_a_run_starts
    first_job = failed_run_in("/project")
    50.times { @recorder.create_run(commit_hash: "abc1234", branch: "main", project_path: "/project") }

    assert_nil job(first_job)[:output_tail]
  end

  def test_should_mark_a_stage_beyond_the_project_s_newest_50_runs_as_pruned
    first_job = failed_run_in("/project")
    50.times { @recorder.create_run(commit_hash: "abc1234", branch: "main", project_path: "/project") }

    assert_equal 1, job(first_job)[:pruned]
  end

  def test_should_keep_output_within_the_project_s_newest_50_runs
    first_job = failed_run_in("/project")
    49.times { @recorder.create_run(commit_hash: "abc1234", branch: "main", project_path: "/project") }

    assert_equal "boom\n", job(first_job)[:output_tail]
  end

  private

  def failed_run_in(project)
    @recorder.create_run(commit_hash: "abc1234", branch: "main", project_path: project)
    @recorder.start_stage("fast").tap do |job_id|
      @recorder.keep_evidence(job_id, FunCi::Evidence::Document.legacy(tail: "boom\n", failures: []))
    end
  end
end
