# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/console/job_rows"
require "fun_ci/persistence/database"
require "fun_ci/persistence/job_recorder"
require "fun_ci/persistence/job_visibility"

# The job section's rows: where each job of the board's projects stands, in
# JobOrder (acceptance-tests.md, AT-13.14), and how the user hid it
# (AT-13.29, AT-13.30). What a standing says is Jobs::Standings'
# (test_job_standings.rb); which jobs are hidden, Persistence::JobVisibility's
# (test_job_visibility.rb).
class TestJobRows < Minitest::Test
  include DatabaseTestSetup

  NOW = Time.utc(2026, 10, 1, 12)

  def setup
    setup_test_db
    @project = File.join(@dir, "project")
    %w[daily/mutation.sh weekly/soak.sh].each { |script| write_job(@project, script) }
  end

  def teardown = teardown_test_db

  def test_should_list_a_failed_job_before_a_due_one
    FunCi::Persistence::JobRecorder.new(@db).end_stage(claim("soak", NOW - 60), "failed")

    assert_equal %w[soak mutation], rows([@project]).map(&:name)
  end

  def test_should_list_no_job_of_a_project_not_on_the_board
    write_job(File.join(@dir, "other"), "daily/lint-deep.sh")

    refute_includes rows([@project]).map(&:name), "lint-deep"
  end

  def test_should_list_the_jobs_of_each_project_on_the_board
    write_job(File.join(@dir, "other"), "daily/lint-deep.sh")

    assert_equal %w[mutation soak lint-deep], rows([@project, File.join(@dir, "other")]).map(&:name)
  end

  def test_should_say_how_a_job_was_hidden
    FunCi::Persistence::JobVisibility.new(@db).hide(@project, "soak", "ignored", at: NOW)

    assert_equal [nil, "ignored"], rows([@project]).map(&:hidden)
  end

  def test_should_say_a_job_is_hidden_in_its_own_project_alone
    write_job(File.join(@dir, "other"), "weekly/soak.sh")
    FunCi::Persistence::JobVisibility.new(@db).hide(File.join(@dir, "other"), "soak", "snoozed", at: NOW)

    assert_equal [nil, nil, "snoozed"], rows([@project, File.join(@dir, "other")]).map(&:hidden)
  end

  private

  def rows(projects) = FunCi::Console::JobRows.new(@db).of(projects, now: NOW)

  def claim(name, at)
    job = FunCi::Jobs::Folders.new(@project).jobs.find { |found| found.name == name }
    FunCi::Persistence::JobRuns.new(@db, @project).claim(job, commit: { sha: "a" * 40, branch: "main" },
                                                              lock_file: "/l", now: at)
  end

  def write_job(project, script)
    path = File.join(project, ".fun-ci", script)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!/bin/sh\n")
    File.chmod(0o755, path)
  end
end
