# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/job_run_kit"
require_relative "../../support/body_script"
require_relative "../../support/process_deadline"

# A job past its budget is killed with its process group, its script run by
# the real process runner (acceptance-tests.md, AT-13.9). That it is recorded
# out of time is decided in memory (test_job_run.rb).
class TestJobOverBudget < Minitest::Test
  include JobRunKit
  include ProcessDeadline

  def test_should_kill_the_process_a_job_past_its_budget_started
    overrun

    assert_raises(Errno::ESRCH) { Process.kill(0, File.read(pid_file).to_i) }
  end

  private

  def pid_file = File.join(@dir, "child.pid")

  # A job whose script starts a child in its group, then waits longer than its budget of a second.
  def overrun
    File.delete(File.join(project, ".fun-ci", "daily", "mutation.sh"))
    BodyScript.write(File.join(project, ".fun-ci", "daily", "mutation.sh"),
                     "sleep 30 &\necho $! > '#{pid_file}'\nwait")
    seams = FunCi::Pipeline::Seams.new(stage_dir: -> { FakeStageDir.new }, time_budgets: { "jobs/mutation" => 1 })
    commit = FunCi::Pipeline::Commit.new(sha: SHA, branch: "main")
    within_deadline { FunCi::Jobs::JobRun.new(job, commit, site, seams).start }
  end
end
