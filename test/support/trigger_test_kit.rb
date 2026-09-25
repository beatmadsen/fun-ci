# frozen_string_literal: true

require "stringio"
require "tmpdir"
require "timeout"
require "fun_ci/pipeline/trigger"

# Builds a Trigger the way tests need one: every commit is valid, the slow
# suite is not launched, and output goes to StringIOs, unless a test says
# otherwise through the same seams production uses.
module TriggerTestKit
  PASS = ["", FakeStatus.new(true, 0)].freeze

  def failing(output) = [output, FakeStatus.new(false, 1)]

  # Answers PASS, or the answer for the first script named in the command.
  # An answer of Timeout::Error blows that stage's budget.
  def scripted_runner(answers = {}, log: [])
    lambda do |cmd|
      log << cmd
      answer = answers.find { |script, _| cmd.include?(script) }&.last || PASS
      answer == Timeout::Error ? raise(Timeout::Error) : answer
    end
  end

  def build_trigger(dir, sha: "abc1234", io: quiet_io, **seams)
    defaults = { commit_validator: ->(_sha) { true }, background_launcher: noop_launcher }
    FunCi::Pipeline::Trigger.new(project: dir, commit: FunCi::Pipeline::Commit.new(sha: sha, branch: "main"),
                                 io: io, seams: FunCi::Pipeline::Seams.new(**defaults, **seams))
  end

  def quiet_io = FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: StringIO.new)
  def noop_launcher = ->(**) {}

  # Runs the slow suite in the calling thread, recording into +recorder+.
  def inline_launcher(recorder = FakeRecorder.new)
    lambda do |job_id:, executor:, **|
      FunCi::Pipeline::BackgroundWrapper.new(recorder: recorder, job_id: job_id, executor: executor).run
    end
  end

  def in_project
    Dir.mktmpdir("fun-ci-test") do |dir|
      make_project_with_scripts(dir)
      yield dir
    end
  end
end
