# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/project_config"
require "tmpdir"

class TestProjectConfigDetection < Minitest::Test
  def test_should_detect_fun_ci_folder_when_present
    # Given a project directory with a .fun-ci folder
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, ".fun-ci"))
      # When we check for the folder
      config = FunCi::Setup::ProjectConfig.new(dir)
      # Then it should be detected
      assert config.folder_exists?, "Should detect .fun-ci folder"
    end
  end

  def test_should_not_detect_fun_ci_folder_when_absent
    # Given a project directory without a .fun-ci folder
    Dir.mktmpdir do |dir|
      # When we check for the folder
      config = FunCi::Setup::ProjectConfig.new(dir)
      # Then it should not be detected
      refute config.folder_exists?, "Should not detect missing .fun-ci folder"
    end
  end
end

class TestProjectConfigValidation < Minitest::Test
  def test_should_validate_when_all_scripts_exist_and_are_executable
    # Given a .fun-ci folder with all four executable scripts
    Dir.mktmpdir do |dir|
      fun_ci_dir = File.join(dir, ".fun-ci")
      FileUtils.mkdir_p(fun_ci_dir)
      %w[lint.sh build.sh fast.sh slow.sh].each do |script|
        path = File.join(fun_ci_dir, script)
        File.write(path, "#!/bin/sh\nexit 0\n")
        File.chmod(0o755, path)
      end
      # When we validate
      config = FunCi::Setup::ProjectConfig.new(dir)
      errors = config.validate
      # Then there should be no errors
      assert_empty errors, "Should have no errors when all scripts are present and executable"
    end
  end

  def test_should_report_missing_script
    # Given a .fun-ci folder with only build.sh
    Dir.mktmpdir do |dir|
      fun_ci_dir = File.join(dir, ".fun-ci")
      FileUtils.mkdir_p(fun_ci_dir)
      path = File.join(fun_ci_dir, "build.sh")
      File.write(path, "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, path)
      # When we validate
      config = FunCi::Setup::ProjectConfig.new(dir)
      errors = config.validate
      # Then errors should mention the missing scripts
      assert_includes errors.join(" "), "fast.sh", "Should report missing fast.sh"
      assert_includes errors.join(" "), "slow.sh", "Should report missing slow.sh"
    end
  end

  def test_should_report_non_executable_script
    # Given a .fun-ci folder with all scripts but fast.sh is not executable
    Dir.mktmpdir do |dir|
      fun_ci_dir = File.join(dir, ".fun-ci")
      FileUtils.mkdir_p(fun_ci_dir)
      %w[lint.sh build.sh fast.sh slow.sh].each do |script|
        path = File.join(fun_ci_dir, script)
        File.write(path, "#!/bin/sh\nexit 0\n")
        File.chmod(0o755, path)
      end
      # Make fast.sh non-executable
      File.chmod(0o644, File.join(fun_ci_dir, "fast.sh"))
      # When we validate
      config = FunCi::Setup::ProjectConfig.new(dir)
      errors = config.validate
      # Then errors should mention fast.sh is not executable
      assert_includes errors.join(" "), "fast.sh", "Should report non-executable fast.sh"
    end
  end

  def test_should_report_missing_folder
    # Given a project directory without .fun-ci
    Dir.mktmpdir do |dir|
      # When we validate
      config = FunCi::Setup::ProjectConfig.new(dir)
      errors = config.validate
      # Then errors should mention the missing folder
      assert errors.any? { |e| e.include?(".fun-ci") }, "Should report missing .fun-ci folder"
    end
  end
end

class TestProjectConfigScriptPaths < Minitest::Test
  def test_should_return_script_path
    # Given a project directory
    Dir.mktmpdir do |dir|
      config = FunCi::Setup::ProjectConfig.new(dir)
      # When we ask for the build script path
      path = config.script_path("build")
      # Then it should return the full path
      assert_equal File.join(dir, ".fun-ci", "build.sh"), path, "Should return full path to build.sh"
    end
  end
end
