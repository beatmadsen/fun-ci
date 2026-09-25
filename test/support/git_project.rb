# frozen_string_literal: true

require "open3"
require "tmpdir"
require "fileutils"

# A temporary git repository with .fun-ci/ stage scripts, for process tests.
class GitProject
  STAGES = %w[lint build fast slow].freeze

  attr_reader :dir

  def self.create
    new(Dir.mktmpdir("git-project")).tap(&:init)
  end

  def initialize(dir)
    @dir = dir
  end

  def init
    git("init", "-q", "-b", "main")
    git("config", "user.name", "fun-ci test")
    git("config", "user.email", "test@example.invalid")
  end

  # Writes one script per stage from the block's body for that stage.
  def write_stage_scripts
    STAGES.each { |stage| write(".fun-ci/#{stage}.sh", "#!/bin/sh\n#{yield stage}\n", mode: 0o755) }
  end

  def write(path, content, mode: 0o644)
    full = File.join(@dir, path)
    FileUtils.mkdir_p(File.dirname(full))
    File.write(full, content)
    File.chmod(mode, full)
  end

  # Commits everything and answers the new commit's SHA.
  def commit(message)
    git("add", "-A")
    git("commit", "-q", "-m", message)
    git("rev-parse", "HEAD").strip
  end

  def git(*args)
    output, status = Open3.capture2e("git", *args, chdir: @dir)
    raise "git #{args.join(" ")} failed: #{output}" unless status.success?

    output
  end

  def common_dir = File.realpath(File.expand_path(git("rev-parse", "--git-common-dir").strip, @dir))
  def remove = FileUtils.rm_rf(@dir)
end
