# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/installer"
require "tmpdir"
require "stringio"

class TestInstallerHappyPath < Minitest::Test
  def test_should_report_detected_language_to_stdout
    # Given a Ruby project directory
    Dir.mktmpdir("fun-ci-installer-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      stdout = StringIO.new

      # When we run the installer
      FunCi::Installer.run(project_root: dir, stdout: stdout)

      # Then stdout should mention Ruby/Bundler
      assert_match(/ruby/i, stdout.string, "Should report detected language")
    end
  end

  def test_should_return_zero_on_success
    # Given a Ruby project directory
    Dir.mktmpdir("fun-ci-installer-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      stdout = StringIO.new

      # When we run the installer
      exit_code = FunCi::Installer.run(project_root: dir, stdout: stdout)

      # Then it should return success
      assert_equal 0, exit_code, "Should return 0 on success"
    end
  end
end

class TestInstallerAlreadyExists < Minitest::Test
  def test_should_refuse_when_fun_ci_directory_already_exists
    # Given a project directory that already has .fun-ci/
    Dir.mktmpdir("fun-ci-installer-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      Dir.mkdir(File.join(dir, ".fun-ci"))
      stdout = StringIO.new

      # When we run the installer
      exit_code = FunCi::Installer.run(project_root: dir, stdout: stdout)

      # Then it should refuse and return failure
      assert_equal 1, exit_code, "Should return 1 when .fun-ci already exists"
      assert_match(/already exists/i, stdout.string, "Should explain why it refused")
    end
  end
end
