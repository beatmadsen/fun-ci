# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/project_config"
require "tmpdir"
require "shellwords"

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

  # `fun-ci check` and every hook's `fun-ci trigger` ask this; a typo in the
  # file died with a stack trace in both.
  def test_should_name_a_config_file_that_is_not_yaml_and_the_line_it_breaks_on
    write_scripts(*SCRIPTS)
    File.write(File.join(fun_ci_dir, "config"), "worktree_slots: 2\nevidence: [\n")

    assert_match(%r{\A\.fun-ci/config is not YAML: .+ \(line 3\)\z}, config.validate.join("\n"))
  end

  def test_should_take_the_default_worktree_slots_when_the_config_is_not_yaml
    FileUtils.mkdir_p(fun_ci_dir)
    File.write(File.join(fun_ci_dir, "config"), "worktree_slots: 3\nevidence: [\n")

    assert_equal 2, config.worktree_slots
  end

  def test_should_place_each_stage_s_script_in_fun_ci
    assert_equal File.join(@dir, ".fun-ci", "build.sh"), config.script_path("build")
  end

  # Every stage failed in a project whose path held a space: the shell
  # split the script's path there.
  def test_should_run_a_stage_s_script_with_the_commit_even_where_the_path_has_a_space
    spaced = FunCi::Setup::ProjectConfig.new(File.join(@dir, "my project"))

    assert_equal [File.join(@dir, "my project", ".fun-ci", "fast.sh"), "abc1234"],
                 Shellwords.split(spaced.stage_command("fast", "abc1234"))
  end

  def test_should_name_the_presets_whose_marker_files_the_project_has
    File.write(File.join(@dir, "Shop.csproj"), "<Project />\n")

    assert_equal ["dotnet-test"], config.presets
  end

  def test_should_name_the_presets_without_markers_apart
    File.write(File.join(@dir, "Shop.csproj"), "<Project />\n")

    assert_equal %w[ecs logstash shellcheck], config.any_project_presets
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
