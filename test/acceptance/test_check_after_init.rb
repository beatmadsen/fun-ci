# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/installer"
require "fun_ci/setup/setup_checker"
require "tmpdir"
require "stringio"

class TestCheckAfterInit < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("fun-ci-wiring-test")
    File.write(File.join(@dir, "Gemfile"), "source 'https://rubygems.org'\n")
    @check_stdout = StringIO.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_should_report_all_clear_after_init
    assert_equal 0, init, "Precondition: init should succeed"
    assert_equal 0, check, "Check should pass after init"
    assert_match(/ok|configured|ready/i, @check_stdout.string, "Should report positive status")
  end

  def test_should_report_issues_when_script_deleted_after_init
    init
    File.delete(File.join(@dir, ".fun-ci", "fast.sh"))
    assert_equal 1, check, "Check should fail with missing script"
    assert_match(/fast\.sh/, @check_stdout.string, "Should report missing fast.sh")
  end

  def test_should_warn_of_each_placeholder_init_left_in_place
    File.delete(File.join(@dir, "Gemfile"))
    init
    check

    assert_includes @check_stdout.string, "Warning: .fun-ci/fast.sh is init's placeholder, " \
                                          "so the fast stage tests nothing: put the project's own in it"
  end

  def test_should_pass_with_placeholders_in_place
    File.delete(File.join(@dir, "Gemfile"))
    init

    assert_equal 0, check
  end

  private

  def init
    FunCi::Setup::Installer.run(project_root: @dir, stdout: StringIO.new)
  end

  def check
    FunCi::Setup::SetupChecker.run(project_root: @dir, stdout: @check_stdout)
  end
end
