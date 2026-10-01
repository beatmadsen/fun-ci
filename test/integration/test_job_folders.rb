# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/jobs/folders"
require "tmpdir"

# The jobs a project keeps in .fun-ci/daily/ and .fun-ci/weekly/ (acceptance-tests.md, AT-13.1, AT-13.2).
class TestJobFolders < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_should_find_a_daily_job_named_after_its_script
    write_job("daily", "mutation.sh")

    assert_equal([%w[mutation daily]], folders.jobs.map { |job| [job.name, job.cadence] })
  end

  def test_should_find_a_weekly_job_named_after_its_script
    write_job("weekly", "soak.sh")

    assert_equal([%w[soak weekly]], folders.jobs.map { |job| [job.name, job.cadence] })
  end

  def test_should_list_the_jobs_by_name
    write_job("weekly", "soak.sh")
    write_job("daily", "mutation.sh")

    assert_equal %w[mutation soak], folders.jobs.map(&:name)
  end

  def test_should_find_no_jobs_without_the_folders
    FileUtils.mkdir_p(File.join(@dir, ".fun-ci"))

    assert_empty folders.jobs
  end

  def test_should_ignore_a_file_that_is_not_a_shell_script
    write_job("daily", "README.md")

    assert_empty folders.jobs
  end

  def test_should_run_a_job_as_its_script_with_the_commit
    write_job("daily", "mutation.sh")

    assert_equal "#{File.join(@dir, ".fun-ci", "daily", "mutation.sh")} abc123", folders.jobs.first.command("abc123")
  end

  def test_should_quote_a_script_path_with_a_space_in_it
    @dir = File.join(@dir, "my project")
    write_job("daily", "mutation.sh")

    assert_includes folders.jobs.first.command("abc123"), "my\\ project"
  end

  def test_should_leave_out_a_script_that_is_not_executable
    write_job("daily", "mutation.sh", mode: 0o644)

    assert_empty folders.jobs
  end

  def test_should_name_a_script_that_is_not_executable
    write_job("daily", "mutation.sh", mode: 0o644)

    assert_equal [".fun-ci/daily/mutation.sh is not executable"], folders.errors
  end

  def test_should_leave_out_a_job_named_in_both_folders
    write_job("daily", "soak.sh")
    write_job("weekly", "soak.sh")

    assert_empty folders.jobs
  end

  def test_should_name_a_job_named_in_both_folders
    write_job("daily", "soak.sh")
    write_job("weekly", "soak.sh")

    assert_equal ["the job soak is in both .fun-ci/daily/ and .fun-ci/weekly/: rename one"], folders.errors
  end

  # Its name goes into commands an agent pastes: fun-ci why --job NAME.
  def test_should_leave_out_a_job_whose_name_a_command_line_would_split
    write_job("daily", "my soak.sh")

    assert_empty folders.jobs
  end

  def test_should_name_a_job_whose_name_a_command_line_would_split
    write_job("daily", "my soak.sh")

    expected = "the job 'my soak' needs a name of letters, digits, '.', '_' and '-': rename .fun-ci/daily/my soak.sh"

    assert_equal [expected], folders.errors
  end

  def test_should_find_nothing_wrong_with_executable_jobs_of_their_own_names
    write_job("daily", "mutation.sh")

    assert_empty folders.errors
  end

  private

  def folders = FunCi::Jobs::Folders.new(@dir)

  def write_job(cadence, name, mode: 0o755)
    path = File.join(@dir, ".fun-ci", cadence, name)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, "#!/bin/sh\n")
    File.chmod(mode, path)
  end
end
