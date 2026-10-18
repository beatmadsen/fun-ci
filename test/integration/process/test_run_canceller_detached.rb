# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/process_deadline"
require_relative "../../support/lifeline"
require_relative "../../support/fifo"
require "tmpdir"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_recorder"
require "fun_ci/persistence/active_runs"
require "fun_ci/pipeline/run_canceller"

# A stage's child that leaves for a session of its own, as Node's detached
# children (Playwright's web server) do, is stopped with the run, so the next
# run finds its port free. Its command line names the test's directory, so
# the stray-process guard stops it if the canceller doesn't.
class TestRunCancellerDetached < Minitest::Test
  include DatabaseTestSetup
  include ProcessDeadline

  ESCAPEE = "perl -MPOSIX -e 'POSIX::setsid(); sleep 300'"

  def setup
    setup_test_db
    recorder = FunCi::Persistence::DbRecorder.new(@db)
    run_id = recorder.create_run(commit_hash: "abc1234", branch: "main", project_path: "/project")
    @stage = start_stage_group(recorder)
    FunCi::Persistence::ActiveRuns.with_id(@db, run_id).each { |run| FunCi::Pipeline::RunCanceller.new.cancel(@db, run) }
    within_deadline { Process.wait(@stage) }
  end

  def teardown
    @lifeline&.close
    teardown_test_db
  end

  def test_should_stop_a_process_a_stage_started_in_a_session_of_its_own
    assert(within_deadline { @lifeline.all_ended? })
  end

  private

  # A stage whose script starts the escapee and waits on it, in a process
  # group of its own, as ProcessRunner starts one, recorded as a pipeline records it.
  def start_stage_group(recorder)
    @lifeline = Lifeline.new(@dir)
    started = File.join(@dir, "started").tap { |fifo| File.mkfifo(fifo) }
    script = "#{@lifeline.hold}; #{ESCAPEE} #{@dir}/escapee & echo $! > #{started}; wait"
    pid = Process.spawn("sh", "-c", script, pgroup: true, %i[out err] => File::NULL)
    recorder.stage_process(recorder.start_stage("slow"), pid)
    in_its_own_session(Integer(Fifo.read(started)))
    pid
  end

  def in_its_own_session(escapee) = within_deadline { nil until Process.getsid(escapee) == escapee }
end
