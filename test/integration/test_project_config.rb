# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/project_config"
require "tmpdir"

module ProjectConfigDir
  def setup
    @dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  private

  def config
    FunCi::Setup::ProjectConfig.new(@dir)
  end

  def fun_ci_dir
    File.join(@dir, ".fun-ci")
  end

  def write_executable_scripts(*scripts)
    FileUtils.mkdir_p(fun_ci_dir)
    scripts.each do |script|
      path = File.join(fun_ci_dir, script)
      File.write(path, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, path)
    end
  end
end

class TestProjectConfigDetection < Minitest::Test
  include ProjectConfigDir

  def test_should_detect_fun_ci_folder_when_present
    FileUtils.mkdir_p(fun_ci_dir)
    assert config.folder_exists?, "Should detect .fun-ci folder"
  end

  def test_should_not_detect_fun_ci_folder_when_absent
    refute config.folder_exists?, "Should not detect missing .fun-ci folder"
  end
end

class TestProjectConfigValidation < Minitest::Test
  include ProjectConfigDir

  ALL_SCRIPTS = %w[lint.sh build.sh fast.sh slow.sh].freeze

  def test_should_validate_when_all_scripts_exist_and_are_executable
    write_executable_scripts(*ALL_SCRIPTS)
    assert_empty config.validate, "Should have no errors when all scripts are present and executable"
  end

  def test_should_report_missing_script
    write_executable_scripts("build.sh")
    errors = config.validate
    assert_includes errors.join(" "), "fast.sh", "Should report missing fast.sh"
    assert_includes errors.join(" "), "slow.sh", "Should report missing slow.sh"
  end

  def test_should_report_non_executable_script
    write_executable_scripts(*ALL_SCRIPTS)
    File.chmod(0o644, File.join(fun_ci_dir, "fast.sh"))
    assert_includes config.validate.join(" "), "fast.sh", "Should report non-executable fast.sh"
  end

  def test_should_report_missing_folder
    assert config.validate.any? { |e| e.include?(".fun-ci") }, "Should report missing .fun-ci folder"
  end
end

class TestProjectConfigScriptPaths < Minitest::Test
  include ProjectConfigDir

  def test_should_return_script_path
    assert_equal File.join(@dir, ".fun-ci", "build.sh"), config.script_path("build"),
                 "Should return full path to build.sh"
  end
end
