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

  # A command runner that answers PASS, or the answer for the first script
  # named in the command, and remembers every command it was given. An answer
  # of Timeout::Error blows that stage's budget.
  class ScriptedRunner
    attr_reader :commands

    def initialize(answers)
      @answers = answers
      @commands = []
    end

    def call(cmd)
      @commands << cmd
      answer = @answers.find { |script, _| cmd.include?(script) }&.last || PASS
      answer == Timeout::Error ? raise(Timeout::Error) : answer
    end

    def ran?(script) = @commands.any? { |cmd| cmd.include?(script) }
    def command_for(script) = @commands.find { |cmd| cmd.include?(script) }.to_s
  end

  Outcome = Data.define(:exit_code, :stdout, :stderr)

  def failing(output) = [output, FakeStatus.new(false, 1)]

  def scripted_runner(answers = {}) = ScriptedRunner.new(answers)

  # Lint answers only after build has finished, so build completes first.
  def build_finishing_first
    build_done = Queue.new
    lambda do |cmd|
      build_done.pop if cmd.include?("lint.sh")
      build_done << true if cmd.include?("build.sh")
      PASS
    end
  end

  def build_trigger(dir, sha: "abc1234", io: quiet_io, **seams)
    defaults = { commit_validator: ->(_sha) { true }, background_launcher: noop_launcher,
                 workspace: FunCi::Pipeline::InPlace.new(dir) }
    FunCi::Pipeline::Trigger.new(project: dir, commit: FunCi::Pipeline::Commit.new(sha: sha, branch: "main"),
                                 io: io, seams: FunCi::Pipeline::Seams.new(**defaults, **seams))
  end

  # Runs a trigger in a fresh project and answers what the user would see.
  def run_in_project(**options)
    io = quiet_io
    exit_code = in_project { |dir| build_trigger(dir, io: io, **options).run }
    Outcome.new(exit_code, io.stdout.string, io.stderr.string)
  end

  # A workspace whose one slot records whether its lock was let go.
  class RecordingWorkspace
    Lock = Struct.new(:closed?) { def close = self[:closed?] = true }

    attr_reader :lock

    def initialize(path)
      @path = path
      @lock = Lock.new(false)
    end

    def acquire(_sha) = FunCi::Pipeline::Slot.new(@path, @lock)
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
