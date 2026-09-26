# frozen_string_literal: true

require_relative "trigger_cli_shared"
require_relative "../support/troubled_db"

# AT-8.2 and AT-8.4: a database that can't take the pipeline's writes doesn't
# stop the pipeline, and fun-ci says so once.
class TestTriggerDatabaseTrouble < Minitest::Test
  def teardown
    @client.close
  end

  def test_should_still_run_every_stage_when_the_database_stays_busy
    trigger_over(SQLite3::BusyException)

    assert(%w[lint.sh build.sh fast.sh slow.sh].all? { |script| @client.ran?(script) })
  end

  def test_should_exit_with_the_pipeline_s_own_code_when_the_database_stays_busy
    trigger_over(SQLite3::BusyException, failures: { "fast.sh" => { exit: 1 } })

    assert_equal 1, @client.exit_code
  end

  def test_should_tell_the_developer_once_that_the_run_was_not_recorded
    trigger_over(SQLite3::BusyException)

    assert_equal 1, @client.stdout.scan("couldn't record this run").size
  end

  def test_should_tell_the_developer_it_cannot_write_to_the_database
    trigger_over(SQLite3::FullException)

    assert_includes @client.stdout, "can't write to the database at #{TroubledDb::PATH}"
  end

  def test_should_still_run_every_stage_when_the_database_cannot_be_written
    trigger_over(SQLite3::FullException)

    assert(%w[lint.sh build.sh fast.sh slow.sh].all? { |script| @client.ran?(script) })
  end

  private

  def trigger_over(error, failures: {})
    @client = TriggerCliClient.open(command_runner: script_simulating_runner(failures: failures),
                                    background_launcher: slow_suite_over(error), recorder: recorder_over(error))
    @client.trigger(commit_hash: "abc1234", branch: "main")
  end

  def recorder_over(error) = FunCi::Persistence::DbRecorder.new(TroubledDb.new(error))

  # Runs the slow suite inline, recording it into the same troubled database.
  def slow_suite_over(error)
    lambda do |job_id:, executor:, **|
      FunCi::Pipeline::BackgroundWrapper.new(recorder: recorder_over(error), job_id: job_id, executor: executor).run
    end
  end
end
