# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/template_writer"
require "tmpdir"

class TestTemplateWriter < Minitest::Test
  SCRIPTS = %w[lint.sh build.sh fast.sh slow.sh].freeze
  DETEKT = { lint_override: "mvn detekt:check" }.freeze

  def test_should_create_fun_ci_directory
    in_written_template(:ruby_bundler) do |dir|
      assert Dir.exist?(File.join(dir, ".fun-ci")), "Should create .fun-ci directory"
    end
  end

  def test_should_create_all_four_scripts
    in_written_template(:ruby_bundler) do |dir|
      SCRIPTS.each { |script| assert File.exist?(script_path(dir, script)), "#{script} should exist" }
    end
  end

  def test_should_make_scripts_executable
    in_written_template(:ruby_bundler) do |dir|
      SCRIPTS.each { |script| assert File.executable?(script_path(dir, script)), "#{script} should be executable" }
    end
  end

  def test_should_write_ruby_bundler_template_with_correct_structure
    in_written_template(:ruby_bundler) do |dir|
      SCRIPTS.each do |script|
        assert File.read(script_path(dir, script)).start_with?("#!/bin/sh"), "#{script} should have shebang"
      end
      assert_match(/bundle exec/, File.read(script_path(dir, "fast.sh")), "fast.sh should use bundler")
    end
  end

  def test_should_write_jvm_gradle_kotlin_template_with_gradlew_commands
    fast_content = written_script(:jvm_gradle_kotlin, "fast.sh")
    assert fast_content.start_with?("#!/bin/sh"), "fast.sh should have shebang"
    assert_match(/gradlew/, fast_content, "fast.sh should use gradlew")
  end

  def test_should_write_jvm_maven_template_with_mvn_commands
    fast_content = written_script(:jvm_maven, "fast.sh")
    assert fast_content.start_with?("#!/bin/sh"), "fast.sh should have shebang"
    assert_match(/mvn/, fast_content, "fast.sh should use mvn")
  end

  def test_lint_override_replaces_default_lint_command
    lint_content = written_script(:jvm_maven, "lint.sh", **DETEKT)
    assert lint_content.start_with?("#!/bin/sh"), "lint.sh should still start with shebang"
    assert_match(/mvn detekt:check/, lint_content, "lint.sh should use the override")
    refute_match(/verify/, lint_content, "lint.sh should not contain the default")
  end

  def test_lint_override_does_not_affect_other_scripts
    build_content = written_script(:jvm_maven, "build.sh", **DETEKT)
    assert_match(/mvn compile/, build_content, "build.sh should still use default")
  end

  private

  def in_written_template(project_type, **options)
    Dir.mktmpdir("fun-ci-writer-test") do |dir|
      FunCi::Setup::TemplateWriter.new(project_type, dir, **options).write
      yield dir
    end
  end

  def written_script(project_type, script, **options)
    in_written_template(project_type, **options) { |dir| File.read(script_path(dir, script)) }
  end

  def script_path(dir, script)
    File.join(dir, ".fun-ci", script)
  end
end
