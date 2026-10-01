# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_recorder"
require "fun_ci/persistence/job_runs"
require "fun_ci/evidence/document"
require "fun_ci/jobs/job"
require "json"

# What a job's run records as it runs, through the calls a stage's recorder
# takes (acceptance-tests.md, AT-13.8, AT-13.10).
class TestJobRecorder < Minitest::Test
  include DatabaseTestSetup

  MUTATION = FunCi::Jobs::Job.new(name: "mutation", cadence: "daily", script: "/p/.fun-ci/daily/mutation.sh")
  DOCUMENT = FunCi::Evidence::Document.legacy(tail: "one\ntwo\n", failures: [])

  def setup
    setup_test_db
    @runs = FunCi::Persistence::JobRuns.new(@db, "/p")
    @id = @runs.claim(MUTATION, commit: { sha: "a" * 40, branch: "main" }, lock_file: "/l", now: Time.now)
    @recorder = FunCi::Persistence::JobRecorder.new(@db)
  end

  def teardown = teardown_test_db

  def test_should_record_the_process_group_the_job_s_script_runs_in
    @recorder.stage_process(@id, 4321)

    assert_equal 4321, job_run[:group_pid]
  end

  def test_should_record_the_process_that_runs_the_job
    @recorder.started_by(@id, 1234)

    assert_equal 1234, job_run[:pid]
  end

  def test_should_record_how_the_job_ended
    @recorder.end_stage(@id, "failed")

    assert_equal "failed", job_run[:status]
  end

  def test_should_record_when_the_job_ended
    @recorder.end_stage(@id, "completed")

    refute_nil job_run[:completed_at]
  end

  def test_should_keep_a_failed_job_s_evidence_as_json
    @recorder.keep_evidence(@id, DOCUMENT)

    assert_equal JSON.parse(JSON.generate(DOCUMENT.to_h)), JSON.parse(job_run[:evidence])
  end

  def test_should_keep_the_last_lines_of_a_failed_job_s_output
    @recorder.keep_evidence(@id, DOCUMENT)

    assert_equal "one\ntwo\n", job_run[:output_tail]
  end

  def test_should_keep_how_the_job_s_process_exited
    @recorder.keep_exit(@id, 3, nil)

    assert_equal 3, job_run[:exit_status]
  end

  def test_should_keep_the_signal_that_ended_the_job_s_process
    @recorder.keep_exit(@id, nil, "KILL")

    assert_equal "KILL", job_run[:signal]
  end

  def test_should_keep_what_a_failed_job_printed_apart_from_the_stages
    @recorder.keep_raw(@id, "the whole output")

    assert_equal "the whole output", FunCi::Persistence::RawOutputs.for_jobs(@db.filename("main")).read(@id)
  end

  def test_should_say_no_stage_ran_beside_a_job
    assert_empty @recorder.alongside(@id)
  end

  private

  def job_run = @runs.latest("mutation")
end
