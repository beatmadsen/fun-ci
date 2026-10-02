# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/agent_instructions"

class TestAgentInstructions < Minitest::Test
  INSTRUCTIONS = FunCi::Setup::AgentInstructions
  MARKER = INSTRUCTIONS::MARKER
  # The section fun-ci 2.0 wrote, before jobs and the trunk.
  OUTDATED = "## fun-ci\n\n#{MARKER}\nThis project runs fun-ci on every commit.\n".freeze

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

  def test_should_bring_an_outdated_section_up_to_date
    assert_equal "# Rules\n\n#{INSTRUCTIONS::SECTION}", INSTRUCTIONS.merged("# Rules\n\n#{OUTDATED}")
  end

  def test_should_keep_what_follows_an_outdated_section
    assert_equal "#{INSTRUCTIONS::SECTION}\n## Testing\n\nRun it.\n",
                 INSTRUCTIONS.merged("#{OUTDATED}\n## Testing\n\nRun it.\n")
  end

  def test_should_bring_up_to_date_a_section_whose_heading_was_taken_away
    assert_equal "# Rules\n\n#{INSTRUCTIONS::SECTION}", INSTRUCTIONS.merged("# Rules\n\n#{MARKER}\nOld words.\n")
  end

  def test_should_say_it_told_agents_when_the_text_had_no_section
    assert_equal "Told agents what to do after a commit, in AGENTS.md.", INSTRUCTIONS.said("# Rules\n", "AGENTS.md")
  end

  def test_should_say_it_brought_an_outdated_section_up_to_date
    assert_equal "Brought the fun-ci section of CLAUDE.md up to date.", INSTRUCTIONS.said(OUTDATED, "CLAUDE.md")
  end

  def test_should_tell_agents_how_to_see_the_daily_and_weekly_jobs
    assert_includes INSTRUCTIONS::SECTION.tr("\n", " "), "`fun-ci jobs` lists the daily and weekly jobs"
  end

  def test_should_tell_agents_how_to_find_out_why_a_job_failed
    assert_includes INSTRUCTIONS::SECTION.tr("\n", " "), "`fun-ci why --job NAME` says why one failed"
  end

  def test_should_tell_agents_to_wait_in_the_background_after_each_commit
    assert_includes INSTRUCTIONS::SECTION.tr("\n", " "), "After each commit, run the `fun-ci wait` command it prints"
  end
end
