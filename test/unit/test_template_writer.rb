# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/template_writer"
require "tmpdir"

class TestTemplateWriter < Minitest::Test
  def test_should_create_fun_ci_directory
    # Given a target directory
    Dir.mktmpdir("fun-ci-writer-test") do |dir|
      writer = FunCi::TemplateWriter.new(:ruby_bundler, dir)

      # When we write the template
      writer.write

      # Then .fun-ci/ should exist
      assert Dir.exist?(File.join(dir, ".fun-ci")), "Should create .fun-ci directory"
    end
  end

  def test_should_create_all_four_scripts
    # Given a target directory
    Dir.mktmpdir("fun-ci-writer-test") do |dir|
      writer = FunCi::TemplateWriter.new(:ruby_bundler, dir)

      # When we write the template
      writer.write

      # Then all four scripts should exist
      %w[lint.sh build.sh fast.sh slow.sh].each do |script|
        path = File.join(dir, ".fun-ci", script)
        assert File.exist?(path), "#{script} should exist"
      end
    end
  end

  def test_should_make_scripts_executable
    # Given a target directory
    Dir.mktmpdir("fun-ci-writer-test") do |dir|
      writer = FunCi::TemplateWriter.new(:ruby_bundler, dir)

      # When we write the template
      writer.write

      # Then all four scripts should be executable
      %w[lint.sh build.sh fast.sh slow.sh].each do |script|
        path = File.join(dir, ".fun-ci", script)
        assert File.executable?(path), "#{script} should be executable"
      end
    end
  end

  def test_should_write_ruby_bundler_template_with_correct_structure
    # Given a target directory
    Dir.mktmpdir("fun-ci-writer-test") do |dir|
      writer = FunCi::TemplateWriter.new(:ruby_bundler, dir)

      # When we write the template
      writer.write

      # Then scripts should have shebang and use bundler
      %w[lint.sh build.sh fast.sh slow.sh].each do |script|
        content = File.read(File.join(dir, ".fun-ci", script))
        assert content.start_with?("#!/bin/sh"), "#{script} should have shebang"
      end

      fast_content = File.read(File.join(dir, ".fun-ci", "fast.sh"))
      assert_match(/bundle exec/, fast_content, "fast.sh should use bundler")
    end
  end

  def test_should_write_jvm_gradle_kotlin_template_with_gradlew_commands
    # Given a target directory
    Dir.mktmpdir("fun-ci-writer-test") do |dir|
      writer = FunCi::TemplateWriter.new(:jvm_gradle_kotlin, dir)

      # When we write the template
      writer.write

      # Then scripts should have shebang and use gradlew
      fast_content = File.read(File.join(dir, ".fun-ci", "fast.sh"))
      assert fast_content.start_with?("#!/bin/sh"), "fast.sh should have shebang"
      assert_match(/gradlew/, fast_content, "fast.sh should use gradlew")
    end
  end

  def test_should_write_jvm_maven_template_with_mvn_commands
    # Given a target directory
    Dir.mktmpdir("fun-ci-writer-test") do |dir|
      writer = FunCi::TemplateWriter.new(:jvm_maven, dir)

      # When we write the template
      writer.write

      # Then scripts should have shebang and use mvn
      fast_content = File.read(File.join(dir, ".fun-ci", "fast.sh"))
      assert fast_content.start_with?("#!/bin/sh"), "fast.sh should have shebang"
      assert_match(/mvn/, fast_content, "fast.sh should use mvn")
    end
  end

  def test_lint_override_replaces_default_lint_command
    # Given a Maven template with a lint override
    Dir.mktmpdir("fun-ci-lint-override") do |dir|
      writer = FunCi::TemplateWriter.new(:jvm_maven, dir, lint_override: "mvn detekt:check")

      # When we write the template
      writer.write

      # Then lint.sh should use the override command and preserve shebang
      lint_content = File.read(File.join(dir, ".fun-ci", "lint.sh"))
      assert lint_content.start_with?("#!/bin/sh"), "lint.sh should still start with shebang"
      assert_match(/mvn detekt:check/, lint_content, "lint.sh should use the override")
      refute_match(/verify/, lint_content, "lint.sh should not contain the default")
    end
  end

  def test_lint_override_does_not_affect_other_scripts
    # Given a Maven template with a lint override
    Dir.mktmpdir("fun-ci-lint-override-other") do |dir|
      writer = FunCi::TemplateWriter.new(:jvm_maven, dir, lint_override: "mvn detekt:check")

      # When we write the template
      writer.write

      # Then other scripts should be unchanged
      build_content = File.read(File.join(dir, ".fun-ci", "build.sh"))
      assert_match(/mvn compile/, build_content, "build.sh should still use default")
    end
  end

end
