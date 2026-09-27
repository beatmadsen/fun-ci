# frozen_string_literal: true

require "fun_ci/evidence/context"
require "fun_ci/evidence/deadline"

# Contexts for built-in extractors, in memory: the output is a string, the
# worktree's files a hash, and the deadline one a test sets.
module EvidenceKit
  # A worktree's files, by path relative to it.
  class FakeWorktree
    def initialize(files = {})
      @files = files
    end

    def read(path) = @files.fetch(path)
    def exist?(path) = @files.key?(path)
    def glob(pattern) = @files.keys.select { |path| File.fnmatch?(pattern, path, File::FNM_PATHNAME) }.sort
  end

  # A deadline that passes after it has been asked `checks` times.
  class PassingDeadline
    def initialize(checks)
      @checks = checks
    end

    def passed? = (@checks -= 1).negative?
  end

  NEVER = FunCi::Evidence::Deadline.new(clock: -> { 0 }, at: 1)

  def context(output: "", files: {}, deadline: NEVER, stage: "fast")
    FunCi::Evidence::Context.new(stage: stage, output: output, worktree: FakeWorktree.new(files), deadline: deadline)
  end
end
