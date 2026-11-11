# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/job_run_kit"
require_relative "../../support/body_script"
require_relative "../../support/fifo"
require_relative "../../support/process_deadline"

# A job past its budget is killed with its process group, its script run by
# the real process runner (acceptance-tests.md, AT-13.9). That it is recorded
# out of time is decided in memory (test_job_run.rb).
class TestJobOverBudget < Minitest::Test
  include JobRunKit
  include ProcessDeadline

  # The child holds the only write end of a FIFO, which closes when it dies
  # and not before, so reading to the end waits for its death itself. Its
  # state in ps would say less: killed at a job's low priority on a busy
  # machine, a process stays runnable until it is scheduled to exit.
  def test_should_kill_the_process_a_job_past_its_budget_started
    File.mkfifo(fifo)
    death = Thread.new { Fifo.read(fifo) }.tap { |thread| thread.report_on_exception = false }
    overrun

    assert_equal("", within_deadline { death.value })
  end

  private

  def fifo = File.join(@dir, "child")

  # A job whose script starts a child in its group, then waits longer than its
  # budget of a second; the child outlives any deadline unless it is killed.
  def overrun
    File.delete(File.join(project, ".fun-ci", "daily", "mutation.sh"))
    BodyScript.write(File.join(project, ".fun-ci", "daily", "mutation.sh"), "sleep 300 3>'#{fifo}' &\nwait")
    seams = FunCi::Pipeline::Seams.new(stage_dir: -> { FakeStageDir.new }, time_budgets: { "jobs/mutation" => 1 })
    commit = FunCi::Pipeline::Commit.new(sha: SHA, branch: "main")
    within_deadline { FunCi::Jobs::JobRun.new(job, commit, site, seams).start }
  end
end
