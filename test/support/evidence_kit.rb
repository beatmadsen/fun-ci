# frozen_string_literal: true

require "fun_ci/evidence/context"
require "fun_ci/evidence/deadline"
require "fun_ci/evidence/stamp"

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

  # watched: the stamps of the worktree's files when the stage started, by path.
  def context(output: "", files: {}, deadline: NEVER, watched: {})
    FunCi::Evidence::Context.new(stage: "fast", output: output, worktree: FakeWorktree.new(files), deadline: deadline,
                                 watched: watched)
  end

  def stamp(size, mtime: 0, inode: 1) = FunCi::Evidence::Stamp.new(size: size, mtime: mtime, inode: inode)
end
