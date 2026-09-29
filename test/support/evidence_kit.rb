# frozen_string_literal: true

require "fun_ci/evidence/context"
require "fun_ci/evidence/deadline"
require "fun_ci/evidence/stamp"
require "fun_ci/evidence/about"

# Contexts for built-in extractors, in memory: the output is a string, the
# worktree's files a hash, and the deadline one a test sets.
module EvidenceKit
  # A worktree's files, by path relative to it. Each file's stamp is its
  # size, with the time and inode a test gives it (0 and 1 otherwise).
  class FakeWorktree
    def initialize(files = {}, stamps = {})
      @files = files
      @stamps = stamps
    end

    def read(path, from: 0) = @files.fetch(path).byteslice(from..)
    def exist?(path) = @files.key?(path)
    def glob(pattern) = @files.keys.select { |path| File.fnmatch?(pattern, path, File::FNM_PATHNAME) }.sort
    def lines_before(path, offset) = @files.fetch(path).byteslice(0, offset).count("\n")

    def stamp(path)
      FunCi::Evidence::Stamp.new(size: @files.fetch(path).bytesize, **@stamps.fetch(path, { mtime: 0, inode: 1 }))
    end
  end

  # A deadline that passes after it has been asked `checks` times.
  class PassingDeadline
    def initialize(checks)
      @checks = checks
    end

    def passed? = (@checks -= 1).negative?
  end

  NEVER = FunCi::Evidence::Deadline.new(clock: -> { 0 }, at: 1)

  # Runs a project's commands without processes: answers what it is told to,
  # and remembers what each was given.
  class FakeCommands
    Ran = Data.define(:stdout, :stderr, :exit_status, :killed)

    attr_reader :given

    def initialize(stdout: "", stderr: "", exit_status: 0, killed: nil)
      @ran = Ran.new(stdout: stdout, stderr: stderr, exit_status: exit_status, killed: killed)
      @given = []
    end

    def call(command, stdin:, seconds:, env: {})
      @given << { command: command, stdin: stdin, seconds: seconds, env: env }
      @ran
    end
  end

  # given: the context's deadline, watched stamps (by path) and commands, where a test names them.
  def context(output: "", files: {}, **given)
    FunCi::Evidence::Context.new(stage: "fast", output: output, worktree: FakeWorktree.new(files), about: ABOUT,
                                 deadline: NEVER, watched: {}, commands: FakeCommands.new, **given)
  end

  ABOUT = FunCi::Evidence::About.new(
    stage: "fast", state: "failed", exit_status: 1, signal: nil, seconds: 8.4, budget: 10, alongside: [],
    commit: { sha: "3f9c2ab", branch: "main" }, worktree: "/slot-1", started_at: "2026-09-27T14:02:11.402Z",
    output: "/state/stages/1-x/output.log"
  )

  def stamp(size, mtime: 0, inode: 1) = FunCi::Evidence::Stamp.new(size: size, mtime: mtime, inode: inode)
end
