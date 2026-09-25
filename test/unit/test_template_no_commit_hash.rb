# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/template_writer"
require "tmpdir"

# The stage tools (rubocop, gradlew, mvn, rake) do not accept a commit hash, so templates must not pass $1.
class TestTemplateNoCommitHash < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("fun-ci-writer-test")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_should_not_pass_commit_hash_to_lint_commands
    write_template(:ruby_bundler)
    assert_match(/rubocop/, script_content("lint.sh"), "Should use rubocop")
    refute_match(/\$1/, script_content("lint.sh"), "lint.sh should not pass $1 to rubocop")
  end

  def test_should_not_pass_commit_hash_to_gradle_lint_commands
    write_template(:jvm_gradle_kotlin)
    assert_match(/gradlew.*check/, script_content("lint.sh"), "Should use gradlew check")
    refute_match(/\$1/, script_content("lint.sh"), "lint.sh should not pass $1 to gradlew check")
  end

  def test_should_not_pass_commit_hash_to_maven_lint_commands
    write_template(:jvm_maven)
    assert_match(/mvn.*verify/, script_content("lint.sh"), "Should use mvn verify")
    refute_match(/\$1/, script_content("lint.sh"), "lint.sh should not pass $1 to mvn verify")
  end

  def test_should_not_pass_commit_hash_to_ruby_test_scripts
    write_template(:ruby_bundler)
    %w[fast.sh slow.sh].each do |script|
      assert_match(/rake test/, script_content(script), "#{script} should use rake test")
      refute_match(/\$1/, script_content(script), "#{script} should not pass $1 to rake test")
    end
  end

  def test_should_not_pass_commit_hash_to_gradle_test_scripts
    write_template(:jvm_gradle_kotlin)
    %w[fast.sh slow.sh].each do |script|
      assert_match(/gradlew/, script_content(script), "#{script} should use gradlew")
      refute_match(/\$1/, script_content(script), "#{script} should not pass $1 to gradlew")
    end
  end

  def test_should_not_pass_commit_hash_to_maven_test_scripts
    write_template(:jvm_maven)
    %w[fast.sh slow.sh].each do |script|
      assert_match(/mvn/, script_content(script), "#{script} should use mvn")
      refute_match(/\$1/, script_content(script), "#{script} should not pass $1 to mvn")
    end
  end

  private

  def write_template(project_type)
    FunCi::Setup::TemplateWriter.new(project_type, @dir).write
  end

  def script_content(script)
    File.read(File.join(@dir, ".fun-ci", script))
  end
end
