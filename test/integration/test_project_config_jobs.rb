# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/project_config"
require "tmpdir"

# The daily and weekly jobs ProjectConfig finds, apart from what a pipeline needs (acceptance-tests.md, AT-13.2).
class TestProjectConfigJobs < Minitest::Test
  SCRIPTS = %w[lint.sh build.sh fast.sh slow.sh daily/mutation.sh].freeze

  def setup
    @dir = Dir.mktmpdir
    write_scripts(*SCRIPTS)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_should_find_the_project_s_daily_and_weekly_jobs
    assert_equal ["mutation"], config.jobs.map(&:name)
  end

  def test_should_name_a_job_that_cannot_run_apart_from_the_pipeline_s_problems
    File.chmod(0o644, File.join(fun_ci_dir, "daily", "mutation.sh"))

    assert_equal [".fun-ci/daily/mutation.sh is not executable"], config.job_errors
  end

  def test_should_not_stop_the_pipeline_for_a_job_that_cannot_run
    File.chmod(0o644, File.join(fun_ci_dir, "daily", "mutation.sh"))

    assert_empty config.validate
  end

  private

  def config = FunCi::Setup::ProjectConfig.new(@dir)
  def fun_ci_dir = File.join(@dir, ".fun-ci")

  def write_scripts(*scripts)
    scripts.each do |script|
      path = File.join(fun_ci_dir, script)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, path)
    end
  end
end
