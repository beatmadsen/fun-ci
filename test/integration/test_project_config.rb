# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/project_config"
require "tmpdir"

# What .fun-ci/ has to hold before fun-ci will run a project's pipeline.
class TestProjectConfig < Minitest::Test
  SCRIPTS = %w[lint.sh build.sh fast.sh slow.sh].freeze

  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_should_see_a_fun_ci_folder_that_is_there
    FileUtils.mkdir_p(fun_ci_dir)

    assert_predicate config, :folder_exists?
  end

  def test_should_not_see_a_fun_ci_folder_that_is_not_there
    refute_predicate config, :folder_exists?
  end

  def test_should_find_nothing_wrong_with_four_executable_scripts
    write_scripts(*SCRIPTS)

    assert_empty config.validate
  end

  def test_should_name_each_missing_script
    write_scripts("build.sh", "lint.sh")

    assert_equal [".fun-ci/fast.sh is not found", ".fun-ci/slow.sh is not found"], config.validate
  end

  def test_should_name_a_script_that_is_not_executable
    write_scripts(*SCRIPTS)
    File.chmod(0o644, File.join(fun_ci_dir, "fast.sh"))

    assert_equal [".fun-ci/fast.sh is not executable"], config.validate
  end

  def test_should_name_the_project_whose_fun_ci_folder_is_missing
    assert_equal ["No .fun-ci/ folder found in #{@dir}"], config.validate
  end

  def test_should_give_two_worktree_slots_when_nothing_says_otherwise
    write_scripts(*SCRIPTS)

    assert_equal 2, config.worktree_slots
  end

  def test_should_give_the_worktree_slots_the_config_file_asks_for
    write_scripts(*SCRIPTS)
    File.write(File.join(fun_ci_dir, "config"), "worktree_slots: 3\n")

    assert_equal 3, config.worktree_slots
  end

  def test_should_name_a_worktree_slot_count_that_is_not_a_whole_number_above_zero
    write_scripts(*SCRIPTS)
    File.write(File.join(fun_ci_dir, "config"), "worktree_slots: 0\n")

    assert_equal [".fun-ci/config: worktree_slots must be a whole number above 0, not 0"], config.validate
  end

  def test_should_name_a_config_file_that_is_not_a_mapping
    write_scripts(*SCRIPTS)
    File.write(File.join(fun_ci_dir, "config"), "- worktree_slots\n")

    assert_equal [".fun-ci/config must be a mapping such as `worktree_slots: 2`"], config.validate
  end

  def test_should_place_each_stage_s_script_in_fun_ci
    assert_equal File.join(@dir, ".fun-ci", "build.sh"), config.script_path("build")
  end

  private

  def config = FunCi::Setup::ProjectConfig.new(@dir)
  def fun_ci_dir = File.join(@dir, ".fun-ci")

  def write_scripts(*scripts)
    FileUtils.mkdir_p(fun_ci_dir)
    scripts.each do |script|
      File.write(File.join(fun_ci_dir, script), "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, File.join(fun_ci_dir, script))
    end
  end
end
