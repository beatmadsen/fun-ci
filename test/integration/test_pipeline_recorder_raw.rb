# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/db_recorder_setup"
require "fun_ci/persistence/raw_outputs"

# A failed stage's raw output is kept for a project's 10 newest runs
# (acceptance-tests.md, AT-10.6; architecture.md, "Evidence of a failed stage").
class TestPipelineRecorderRaw < Minitest::Test
  include DbRecorderTestSetup

  def test_should_keep_a_stage_s_raw_output_beside_the_database
    job_id = failed_run_in("/project")

    assert_equal "boom\n", raw.read(job_id)
  end

  def test_should_keep_the_raw_output_of_the_project_s_10th_newest_run
    job_id = failed_run_in("/project")
    9.times { new_run_in("/project") }

    assert_equal "boom\n", raw.read(job_id)
  end

  def test_should_drop_the_raw_output_of_the_project_s_11th_newest_run_when_a_run_starts
    job_id = failed_run_in("/project")
    10.times { new_run_in("/project") }

    assert_nil raw.read(job_id)
  end

  def test_should_keep_the_raw_output_of_another_project_s_runs
    job_id = failed_run_in("/other")
    10.times { new_run_in("/project") }

    assert_equal "boom\n", raw.read(job_id)
  end

  def test_should_drop_raw_output_whose_stage_no_longer_exists_when_a_run_starts
    raw.write(999, "orphan\n")
    new_run_in("/project")

    assert_nil raw.read(999)
  end

  def test_should_carry_on_when_the_raw_output_cannot_be_written
    new_run_in("/project")
    job_id = @recorder.start_stage("fast")
    File.write(File.join(File.dirname(@db.filename("main")), "raw"), "a file where the directory would go")

    assert_nil @recorder.keep_raw(job_id, "boom\n")
  end

  private

  def raw = FunCi::Persistence::RawOutputs.beside(@db.filename("main"))
  def new_run_in(project) = @recorder.create_run(commit_hash: "abc1234", branch: "main", project_path: project)

  def failed_run_in(project)
    new_run_in(project)
    @recorder.start_stage("fast").tap { |job_id| @recorder.keep_raw(job_id, "boom\n") }
  end
end
