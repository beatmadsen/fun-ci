# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/evidence_kit"
require "fun_ci/evidence/extractors/command"
require "json"

# A project's own extractor: a command given the context on stdin, whose
# stdout is evidence (why.md, "Your own extractor").
class TestCommand < Minitest::Test
  include EvidenceKit

  REPORT = { schema: 1, facts: [{ name: "module", value: "core" }],
             failures: [{ test: "T#a", file: "a.kt", line: 4, message: "m", output: "o" }],
             excerpts: [{ title: "Report", location: "build/r.html", lines: ["x"] }] }.freeze

  def test_should_give_the_command_the_context_on_stdin
    commands = FakeCommands.new
    extract({ "run" => "./x", "module" => "core" }, commands)

    assert_equal({ "module" => "core" }, JSON.parse(commands.given.first[:stdin])["options"])
  end

  def test_should_give_the_command_what_is_left_of_the_budget
    commands = FakeCommands.new
    extract({ "run" => "./x" }, commands)

    assert_in_delta 1.0, commands.given.first[:seconds]
  end

  def test_should_take_what_the_command_prints_as_one_excerpt_titled_with_it
    found = extract({ "run" => "./x" }, FakeCommands.new(stdout: "one\ntwo\n"))

    assert_equal [{ title: "./x", location: "stdout", lines: %w[one two] }], found.excerpts
  end

  def test_should_read_the_facts_a_json_command_prints
    assert_equal [{ name: "module", value: "core" }], json_found(JSON.generate(REPORT)).facts
  end

  def test_should_read_the_failures_a_json_command_prints
    assert_equal [{ test: "T#a", file: "a.kt", line: 4, message: "m", output: "o" }],
                 json_found(JSON.generate(REPORT)).failures
  end

  def test_should_read_the_excerpts_a_json_command_prints
    assert_equal [{ title: "Report", location: "build/r.html", lines: ["x"] }],
                 json_found(JSON.generate(REPORT)).excerpts
  end

  def test_should_ignore_a_field_it_does_not_know
    assert_equal [{ name: "module", value: "core" }],
                 json_found(JSON.generate(REPORT.merge(colour: "blue",
                                                       facts: [{
                                                         name: "module", value: "core", x: 1
                                                       }]))).facts
  end

  def test_should_refuse_a_command_that_exits_other_than_0_with_its_last_20_lines_of_stderr
    commands = FakeCommands.new(exit_status: 2, stderr: (1..25).map { |n| "e#{n}\n" }.join)

    assert_equal "exited 2: #{(6..25).map { |n| "e#{n}" }.join("\n")}", problem({ "run" => "./x" }, commands)
  end

  def test_should_refuse_a_document_that_does_not_parse
    assert_match(/\Aprinted JSON that doesn't parse: /,
                 problem({ "run" => "./x", "format" => "json" }, FakeCommands.new(stdout: "{")))
  end

  def test_should_refuse_a_field_of_the_wrong_type
    assert_equal "printed 'facts' that isn't a list of objects",
                 problem({ "run" => "./x", "format" => "json" }, FakeCommands.new(stdout: '{"facts": "many"}'))
  end

  def test_should_refuse_a_document_of_a_higher_schema
    assert_equal "printed schema 2, and this fun-ci reads schema 1",
                 problem({ "run" => "./x", "format" => "json" }, FakeCommands.new(stdout: '{"schema": 2}'))
  end

  def test_should_say_it_killed_a_command_the_budget_ran_out_on
    assert_equal "killed: still running when the evidence budget ran out",
                 problem({ "run" => "./x" }, FakeCommands.new(killed: :budget, exit_status: nil))
  end

  def test_should_say_it_killed_a_command_that_printed_too_much
    assert_equal "killed: printed more than 256 KB", problem({ "run" => "./x" }, FakeCommands.new(killed: :overflow))
  end

  private

  def json_found(stdout) = extract({ "run" => "./x", "format" => "json" }, FakeCommands.new(stdout: stdout))

  def extract(options, commands)
    deadline = FunCi::Evidence::Deadline.new(clock: -> { 0 }, at: 1)
    FunCi::Evidence::Extractors::Command.new(options).extract(context(commands: commands, deadline: deadline))
  end

  def problem(options, commands)
    assert_raises(FunCi::Evidence::Problem) { extract(options, commands) }.message
  end
end
