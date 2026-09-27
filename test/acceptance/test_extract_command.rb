# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
require "stringio"
require "json"
require "fun_ci/evidence/extract_command"
require "fun_ci/pipeline/trigger_params"

# `fun-ci extract` tries a stage's extractors on a saved output
# (acceptance-tests.md, AT-10.16), so a project can write or change one
# without making a commit.
class TestExtractCommand < Minitest::Test
  CONFIG = <<~YAML
    evidence:
      stages:
        fast:
          - use: grep
            patterns: ["ERROR"]
  YAML

  def setup
    @project = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@project, ".fun-ci"))
    File.write(File.join(@project, ".fun-ci", "config"), CONFIG)
    File.write(File.join(@project, "failing-run.log"), "starting\nERROR: connection refused\ndone\n")
  end

  def teardown = FileUtils.rm_rf(@project)

  def test_should_print_the_grep_excerpt_why_would_print
    extract("fast", "--output", "failing-run.log")

    assert_includes @stdout.string, "from grep:\n  ERROR: connection refused\n"
  end

  def test_should_say_it_had_no_start_sizes
    extract("fast", "--output", "failing-run.log")

    assert_includes @stdout.string,
                    "  start sizes: none, so files are read whole and every watched file counts as changed\n"
  end

  def test_should_print_the_evidence_as_json_when_asked
    extract("fast", "--output", "failing-run.log", "--json")

    excerpts = JSON.parse(@stdout.string).dig("evidence", "excerpts")

    assert_equal(%w[grep output-tail], excerpts.map { |excerpt| excerpt["extractor"] })
  end

  def test_should_say_there_was_no_process_group_after_an_overrun
    extract("fast", "--output", "failing-run.log", "--timed-out")

    assert_includes @stdout.string, "  process group: none, so entries with on: overrun don't run\n"
  end

  def test_should_read_the_reports_it_is_given
    FileUtils.mkdir_p(File.join(@project, "reports"))
    File.write(File.join(@project, "reports", "r.json"), %({"failures": [{"test": "T#a", "message": "m"}]}))
    extract("fast", "--output", "failing-run.log", "--reports", "reports")

    assert_includes @stdout.string, "Failures, from test-reports:\n  T#a\n"
  end

  def test_should_refuse_a_stage_it_does_not_know
    assert_equal 64, extract("quick", "--output", "failing-run.log")
  end

  def test_should_say_why_it_refuses_a_stage
    extract("quick", "--output", "failing-run.log")

    assert_equal "fun-ci extract: name one stage of lint, build, fast, slow, not quick\n", @stdout.string
  end

  def test_should_give_no_exit_status_for_an_overrun
    extract("fast", "--output", "failing-run.log", "--timed-out", "--json")

    assert_nil JSON.parse(@stdout.string)["exit_status"]
  end

  def test_should_credit_its_notes_to_itself
    extract("fast", "--output", "failing-run.log", "--json")

    assert_equal ["fun-ci extract"], JSON.parse(@stdout.string).dig("evidence", "facts").map { |f| f["extractor"] }.uniq
  end

  def test_should_start_with_how_the_stage_ended
    extract("fast", "--output", "failing-run.log", "--exit", "2")

    assert_equal "fast failed (exit 2)", @stdout.string.lines.first.chomp
  end

  private

  def extract(*args)
    @stdout = StringIO.new
    io = FunCi::Pipeline::Io.new(stdout: @stdout, stderr: @stdout)
    FunCi::Evidence::ExtractCommand.new(@project, io).run(args)
  end
end
