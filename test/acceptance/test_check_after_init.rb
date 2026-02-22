# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/installer"
require "fun_ci/setup/setup_checker"
require "tmpdir"
require "stringio"

class TestCheckAfterInit < Minitest::Test
  def test_should_report_all_clear_after_init
    # Given a Ruby project where init has been run
    Dir.mktmpdir("fun-ci-wiring-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      init_exit = FunCi::Setup::Installer.run(project_root: dir, stdout: StringIO.new)
      assert_equal 0, init_exit, "Precondition: init should succeed"

      # When we run check
      check_stdout = StringIO.new
      check_exit = FunCi::Setup::SetupChecker.run(project_root: dir, stdout: check_stdout)

      # Then check should report all clear
      assert_equal 0, check_exit, "Check should pass after init"
      assert_match(/ok|configured|ready/i, check_stdout.string, "Should report positive status")
    end
  end

  def test_should_report_issues_when_script_deleted_after_init
    # Given a Ruby project where init has been run but a script was deleted
    Dir.mktmpdir("fun-ci-wiring-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      FunCi::Setup::Installer.run(project_root: dir, stdout: StringIO.new)
      File.delete(File.join(dir, ".fun-ci", "fast.sh"))

      # When we run check
      check_stdout = StringIO.new
      check_exit = FunCi::Setup::SetupChecker.run(project_root: dir, stdout: check_stdout)

      # Then check should report the missing script
      assert_equal 1, check_exit, "Check should fail with missing script"
      assert_match(/fast\.sh/, check_stdout.string, "Should report missing fast.sh")
    end
  end
end
