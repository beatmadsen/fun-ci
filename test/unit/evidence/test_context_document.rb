# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/evidence_kit"
require "fun_ci/evidence/context_document"

# The context a project's command reads on stdin (why.md, "Your own extractor").
class TestContextDocument < Minitest::Test
  include EvidenceKit

  ABOUT = FunCi::Evidence::About.new(
    stage: "fast", state: "failed", exit_status: 1, signal: nil, seconds: 8.4, budget: 10, alongside: ["slow"],
    commit: { sha: "3f9c2ab", branch: "main" }, worktree: "/slot-1", started_at: "2026-09-27T14:02:11.402Z",
    output: "/state/stages/1-x/output.log", reports: "/state/stages/1-x/reports"
  )

  def test_should_say_how_the_stage_ended
    assert_equal({ schema: 1, stage: "fast", state: "failed", exit_status: 1, signal: nil, seconds: 8.4, budget: 10 },
                 document.slice(:schema, :stage, :state, :exit_status, :signal, :seconds, :budget))
  end

  def test_should_say_where_the_output_and_reports_are
    assert_equal ["/state/stages/1-x/output.log", "/state/stages/1-x/reports"], document.values_at(:output, :reports)
  end

  def test_should_list_the_files_under_the_watch_globs_the_stage_wrote
    assert_equal ["log/new.log", "log/old.log"], document[:changed]
  end

  def test_should_give_each_watched_file_that_existed_the_size_it_had
    assert_equal [{ path: "log/old.log", offset: 3 }, { path: "log/same.log", offset: 2 }], document[:watched]
  end

  def test_should_pass_on_whatever_else_the_entry_said
    assert_equal({ "module" => "core" }, document[:options])
  end

  private

  def document
    context = context(files: { "log/old.log" => "abcdef", "log/new.log" => "x", "log/same.log" => "yz" },
                      watched: { "log/old.log" => stamp(3), "log/same.log" => stamp(2) })
    FunCi::Evidence::ContextDocument.for(ABOUT, context, watch: ["log/*.log"], options: { "module" => "core" })
  end
end
