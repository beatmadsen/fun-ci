# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
require "fun_ci/setup/project_config"

class TestProjectConfigLintScript < Minitest::Test
  def test_should_require_lint_script_to_exist
    # Given a project with build, fast, slow but NO lint.sh
    Dir.mktmpdir("fun-ci-test") do |dir|
      fun_ci_dir = File.join(dir, ".fun-ci")
      Dir.mkdir(fun_ci_dir)
      %w[build.sh fast.sh slow.sh].each do |script|
        path = File.join(fun_ci_dir, script)
        File.write(path, "#!/bin/sh\nexit 0\n")
        File.chmod(0o755, path)
      end
      config = FunCi::Setup::ProjectConfig.new(dir)
      # When validating
      errors = config.validate
      # Then it should report lint.sh is missing
      assert errors.any? { |e| e.include?("lint.sh") },
        "Should report lint.sh is not found, got: #{errors.inspect}"
    end
  end

  def test_should_require_lint_script_to_be_executable
    # Given a project with all scripts, but lint.sh is not executable
    Dir.mktmpdir("fun-ci-test") do |dir|
      fun_ci_dir = File.join(dir, ".fun-ci")
      Dir.mkdir(fun_ci_dir)
      %w[build.sh fast.sh slow.sh].each do |script|
        path = File.join(fun_ci_dir, script)
        File.write(path, "#!/bin/sh\nexit 0\n")
        File.chmod(0o755, path)
      end
      lint_path = File.join(fun_ci_dir, "lint.sh")
      File.write(lint_path, "#!/bin/sh\nexit 0\n")
      File.chmod(0o644, lint_path) # not executable
      config = FunCi::Setup::ProjectConfig.new(dir)
      # When validating
      errors = config.validate
      # Then it should report lint.sh is not executable
      assert errors.any? { |e| e.include?("lint.sh") && e.include?("not executable") },
        "Should report lint.sh is not executable, got: #{errors.inspect}"
    end
  end

  def test_should_pass_validation_when_all_four_scripts_exist_and_are_executable
    # Given a project with all four scripts present and executable
    Dir.mktmpdir("fun-ci-test") do |dir|
      fun_ci_dir = File.join(dir, ".fun-ci")
      Dir.mkdir(fun_ci_dir)
      %w[lint.sh build.sh fast.sh slow.sh].each do |script|
        path = File.join(fun_ci_dir, script)
        File.write(path, "#!/bin/sh\nexit 0\n")
        File.chmod(0o755, path)
      end
      config = FunCi::Setup::ProjectConfig.new(dir)
      # When validating
      errors = config.validate
      # Then there should be no errors
      assert_empty errors, "Should pass with all four scripts, got: #{errors.inspect}"
    end
  end
end
