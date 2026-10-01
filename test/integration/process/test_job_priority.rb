# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/job_run_kit"
require_relative "../../support/body_script"
require_relative "../../support/process_deadline"
require "fun_ci/pipeline/priorities"

# A job's script runs at the priority it is given, by the real process
# runner, so it gives way to the stages a push waits for (AT-13.27). Which
# priority each platform gives is decided in memory (test_priorities.rb).
class TestJobPriority < Minitest::Test
  include JobRunKit
  include ProcessDeadline

  def test_should_run_the_job_s_script_at_the_job_priority
    run_niced_job

    assert_equal "7", File.read(niceness).strip
  end

  private

  def niceness = File.join(@dir, "niceness")

  def run_niced_job
    File.delete(File.join(project, ".fun-ci", "daily", "mutation.sh"))
    BodyScript.write(File.join(project, ".fun-ci", "daily", "mutation.sh"), "echo $(ps -o nice= -p $$) > '#{niceness}'")
    seams = FunCi::Pipeline::Seams.new(stage_dir: -> { FakeStageDir.new },
                                       priorities: FunCi::Pipeline::Priorities.new(job: "nice -n 7 ", slow: ""))
    within_deadline { FunCi::Jobs::JobRun.new(job, FunCi::Pipeline::Commit.new(sha: SHA, branch: "main"), site, seams).start }
  end
end
