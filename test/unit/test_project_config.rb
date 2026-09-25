# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
require "fun_ci/setup/project_config"

class TestProjectConfigLintScript < Minitest::Test
  EXECUTABLE = 0o755
  NOT_EXECUTABLE = 0o644

  def test_should_require_lint_script_to_exist
    errors = validation_errors("build.sh" => EXECUTABLE, "fast.sh" => EXECUTABLE, "slow.sh" => EXECUTABLE)
    assert errors.any? { |e| e.include?("lint.sh") },
           "Should report lint.sh is not found, got: #{errors.inspect}"
  end

  def test_should_require_lint_script_to_be_executable
    errors = validation_errors("build.sh" => EXECUTABLE, "fast.sh" => EXECUTABLE, "slow.sh" => EXECUTABLE,
                               "lint.sh" => NOT_EXECUTABLE)
    assert errors.any? { |e| e.include?("lint.sh") && e.include?("not executable") },
           "Should report lint.sh is not executable, got: #{errors.inspect}"
  end

  def test_should_pass_validation_when_all_four_scripts_exist_and_are_executable
    errors = validation_errors("lint.sh" => EXECUTABLE, "build.sh" => EXECUTABLE, "fast.sh" => EXECUTABLE,
                               "slow.sh" => EXECUTABLE)
    assert_empty errors, "Should pass with all four scripts, got: #{errors.inspect}"
  end

  private

  def validation_errors(script_modes)
    Dir.mktmpdir("fun-ci-test") do |dir|
      fun_ci_dir = File.join(dir, ".fun-ci")
      Dir.mkdir(fun_ci_dir)
      script_modes.each { |script, mode| write_script(File.join(fun_ci_dir, script), mode) }
      FunCi::Setup::ProjectConfig.new(dir).validate
    end
  end

  def write_script(path, mode)
    File.write(path, "#!/bin/sh\nexit 0\n")
    File.chmod(mode, path)
  end
end
