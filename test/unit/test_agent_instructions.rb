# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/agent_instructions"

class TestAgentInstructions < Minitest::Test
  INSTRUCTIONS = FunCi::Setup::AgentInstructions

  def test_should_write_agents_md_when_the_project_has_neither_file
    assert_equal "AGENTS.md", INSTRUCTIONS.file_for(%w[Gemfile])
  end

  def test_should_write_claude_md_when_it_is_the_only_one
    assert_equal "CLAUDE.md", INSTRUCTIONS.file_for(%w[CLAUDE.md Gemfile])
  end

  def test_should_prefer_agents_md_when_the_project_has_both
    assert_equal "AGENTS.md", INSTRUCTIONS.file_for(%w[AGENTS.md CLAUDE.md])
  end

  def test_should_make_an_empty_file_the_section_alone
    assert_equal INSTRUCTIONS::SECTION, INSTRUCTIONS.merged("")
  end

  def test_should_add_the_section_after_what_is_there_with_a_blank_line_between
    assert_equal "# Rules\n\n#{INSTRUCTIONS::SECTION}", INSTRUCTIONS.merged("# Rules\n\n")
  end

  def test_should_add_nothing_to_text_that_has_the_section
    assert_nil INSTRUCTIONS.merged("# Rules\n\n#{INSTRUCTIONS::SECTION}")
  end

  def test_should_tell_agents_to_wait_in_the_background_after_each_commit
    assert_includes INSTRUCTIONS::SECTION.tr("\n", " "), "After each commit, run the `fun-ci wait` command it prints"
  end
end
