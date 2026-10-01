# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/job_run_kit"

# Every job has a day to run, a weekly one too, and records the budget it ran
# to, which why --job says (acceptance-tests.md, AT-13.9, AT-13.21).
class TestJobRunBudget < Minitest::Test
  include JobRunKit

  def test_should_give_a_daily_job_a_day
    run_job

    assert_equal 86_400, latest[:budget]
  end

  def test_should_give_a_weekly_job_a_day_too
    write_script(File.join(project, ".fun-ci", "weekly", "soak.sh"))
    run_job(job: FunCi::Jobs::Folders.new(project).jobs.find { |job| job.name == "soak" })

    assert_equal 86_400, runs.latest("soak")[:budget]
  end

  def test_should_give_a_job_the_budget_a_test_sets_in_place_of_a_day
    run_job(time_budgets: { "jobs/mutation" => 1 })

    assert_equal 1, latest[:budget]
  end
end
