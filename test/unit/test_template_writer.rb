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

      # Then scripts should have shebang, use bundler, and reference $1
      %w[lint.sh build.sh fast.sh slow.sh].each do |script|
        content = File.read(File.join(dir, ".fun-ci", script))
        assert content.start_with?("#!/bin/sh"), "#{script} should have shebang"
      end

      fast_content = File.read(File.join(dir, ".fun-ci", "fast.sh"))
      assert_match(/bundle exec/, fast_content, "fast.sh should use bundler")
      assert_match(/\$1/, fast_content, "fast.sh should reference commit hash argument")

      slow_content = File.read(File.join(dir, ".fun-ci", "slow.sh"))
      assert_match(/\$1/, slow_content, "slow.sh should reference commit hash argument")
    end
  end
end
