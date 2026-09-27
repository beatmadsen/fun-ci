# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/db_recorder_setup"

# Which other stages of a run were running at any moment between a stage's
# start and now (why.md, "Where evidence can come from").
class TestStageAlongside < Minitest::Test
  include DbRecorderTestSetup

  def setup
    super
    create_run
  end

  def test_should_name_a_stage_still_running
    @recorder.start_stage("slow")

    assert_equal %w[slow], @recorder.alongside(@recorder.start_stage("fast"))
  end

  def test_should_name_a_stage_that_finished_after_this_one_started
    build = @recorder.start_stage("build")
    lint = @recorder.start_stage("lint")
    @db.execute("UPDATE stage_jobs SET status = 'completed', completed_at = '2999-01-01T00:00:00.000Z' WHERE id = ?",
                [build])

    assert_equal %w[build], @recorder.alongside(lint)
  end

  def test_should_not_name_a_stage_that_finished_before_this_one_started
    lint = @recorder.start_stage("lint")
    @recorder.end_stage(lint, "completed")
    backdate(lint)

    assert_empty @recorder.alongside(@recorder.start_stage("fast"))
  end

  def test_should_not_name_a_stage_that_finished_the_moment_this_one_started
    lint = @recorder.start_stage("lint")
    fast = @recorder.start_stage("fast")
    @db.execute("UPDATE stage_jobs SET status = 'completed', completed_at = " \
                "(SELECT started_at FROM stage_jobs WHERE id = ?) WHERE id = ?", [fast, lint])

    assert_empty @recorder.alongside(fast)
  end

  private

  def backdate(job_id)
    @db.execute("UPDATE stage_jobs SET started_at = '2020-01-01T00:00:00.000Z', completed_at = " \
                "'2020-01-01T00:00:01.000Z' WHERE id = ?", [job_id])
  end
end
