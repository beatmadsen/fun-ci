# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/settings"

# .fun-ci/config as YAML: anchors and aliases are read, and YAML that loads
# no settings is named as the file's mistake rather than raised.
class TestSettingsYaml < Minitest::Test
  ALIASED = "base: &slots 3\nworktree_slots: *slots\n"
  DATED = "worktree_slots: 3\nsince: 2026-10-01\n"

  def test_should_read_a_setting_given_through_an_alias
    assert_equal 3, settings(ALIASED).worktree_slots
  end

  def test_should_find_nothing_wrong_with_a_config_that_uses_an_alias
    assert_empty settings(ALIASED).errors
  end

  def test_should_name_a_config_whose_yaml_holds_a_value_settings_cannot_hold
    assert_equal [".fun-ci/config can't be read: Tried to load unspecified class: Date " \
                  "(quote a value such as a date to read it as text)"], settings(DATED).errors
  end

  def test_should_take_the_default_worktree_slots_when_the_yaml_cannot_be_read
    assert_equal 2, settings(DATED).worktree_slots
  end

  def test_should_name_no_trunk_when_the_yaml_cannot_be_read
    assert_nil settings("trunk: main\nsince: 2026-10-01\n").trunk
  end

  private

  def settings(text) = FunCi::Setup::Settings.new(text)
end
