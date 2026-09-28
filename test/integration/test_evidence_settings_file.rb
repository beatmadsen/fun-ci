# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
require "fun_ci/evidence/settings"

# The evidence settings as read from .fun-ci/config. A file that can't be
# read as settings gives the defaults, so collecting evidence still works;
# `fun-ci check` is where a mistake in it is reported.
class TestEvidenceSettingsFile < Minitest::Test
  def setup = @dir = Dir.mktmpdir
  def teardown = FileUtils.remove_entry(@dir)

  def test_should_read_the_budget_the_file_gives
    assert_in_delta 5.0, budget_from("evidence:\n  budget: 5\n")
  end

  def test_should_give_the_defaults_without_a_file
    assert_in_delta 2.0, FunCi::Evidence::Settings.load(File.join(@dir, "config")).budget
  end

  def test_should_give_the_defaults_for_a_file_that_is_not_yaml
    assert_in_delta 2.0, budget_from("evidence: [\n")
  end

  def test_should_give_the_defaults_for_a_file_that_holds_a_list
    assert_in_delta 2.0, budget_from("- evidence\n")
  end

  private

  def budget_from(config)
    File.write(File.join(@dir, "config"), config)
    FunCi::Evidence::Settings.load(File.join(@dir, "config")).budget
  end
end
