# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/evidence/catalog"

# The built-in extractors by name, each with the options it takes, which is
# how an entry in .fun-ci/config is checked (why.md, "Configuration").
class TestCatalog < Minitest::Test
  CATALOG = FunCi::Evidence::Catalog

  def test_should_name_an_entry_for_a_built_in_by_the_built_in
    assert_equal "grep", CATALOG.entry({ "use" => "grep", "patterns" => ["ERROR"] }).name
  end

  def test_should_build_the_built_in_an_entry_names
    assert_instance_of FunCi::Evidence::Extractors::Grep,
                       CATALOG.entry({ "use" => "grep", "patterns" => ["ERROR"] }).extractor
  end

  def test_should_refuse_an_extractor_it_does_not_know
    assert_equal "unknown extractor 'nosuch'", refusal({ "use" => "nosuch" })
  end

  def test_should_refuse_an_option_the_built_in_does_not_take
    assert_equal "grep doesn't take 'colour'", refusal({ "use" => "grep", "patterns" => ["x"], "colour" => true })
  end

  def test_should_refuse_an_entry_without_an_option_the_built_in_needs
    assert_equal "grep needs 'patterns'", refusal({ "use" => "grep" })
  end

  def test_should_refuse_a_pattern_that_does_not_compile
    assert_match(/\Agrep: 'patterns' has '\(', which doesn't compile: /,
                 refusal({ "use" => "grep", "patterns" => ["("] }))
  end

  def test_should_refuse_a_count_that_is_not_a_whole_number
    assert_equal "grep: 'context' must be a whole number, not \"3\"",
                 refusal({ "use" => "grep", "patterns" => ["x"], "context" => "3" })
  end

  def test_should_refuse_an_entry_that_is_not_a_mapping
    assert_equal "an entry must be a mapping with use: or run:, not \"grep\"", refusal("grep")
  end

  def test_should_take_an_entry_to_run_on_an_overrun
    assert_equal "overrun", CATALOG.entry({ "use" => "grep", "patterns" => ["x"], "on" => "overrun" }).on
  end

  def test_should_refuse_to_run_an_entry_on_anything_but_an_overrun
    assert_equal "grep: 'on' must be overrun, not \"success\"",
                 refusal({ "use" => "grep", "patterns" => ["x"], "on" => "success" })
  end

  def test_should_name_a_command_entry_by_its_command
    assert_equal "run:.fun-ci/evidence/x", CATALOG.entry({ "run" => ".fun-ci/evidence/x" }).name
  end

  def test_should_refuse_a_command_entry_with_a_format_it_does_not_know
    assert_equal "run:x: 'format' must be text or json, not \"xml\"", refusal({ "run" => "x", "format" => "xml" })
  end

  def test_should_refuse_a_command_entry_without_a_command
    assert_equal "run: must name a command, not nil", refusal({ "run" => nil })
  end

  private

  def refusal(entry) = assert_raises(CATALOG::Refused) { CATALOG.entry(entry) }.message
end
