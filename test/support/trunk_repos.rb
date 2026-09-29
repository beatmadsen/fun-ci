# frozen_string_literal: true

require "open3"
require "tmpdir"
require "fileutils"

# A project cloned from a bare remote, and a teammate's clone that pushes to
# the remote's main, for process tests of the trunk check. Everything lives
# under one temp directory.
class TrunkRepos
  attr_reader :project

  def self.create(files = { "shared.txt" => "one\ntwo\nthree\n" })
    new(Dir.mktmpdir("trunk-repos")).tap { |repos| repos.seed(files) }
  end

  def initialize(root)
    @root = root
    @project = File.join(root, "project")
  end

  def seed(files)
    git(@root, "init", "-q", "--bare", "-b", "main", remote)
    git(@root, "clone", "-q", remote, teammate)
    commit_files(teammate, files, "seed")
    git(teammate, "push", "-q", "origin", "main")
    git(@root, "clone", "-q", remote, @project)
    identify(@project)
  end

  # The teammate commits files on main and pushes; answers the new SHA.
  def upstream(files, message = "upstream")
    sha = commit_files(teammate, files, message)
    git(teammate, "push", "-q", "origin", "main")
    sha
  end

  # The project commits files on its branch, creating the branch from HEAD if new.
  def work(files, branch = "feat/cart", message = "work")
    git(@project, "checkout", "-q", "-B", branch) unless current_branch == branch
    commit_files(@project, files, message)
  end

  def git(dir, *args)
    output, status = Open3.capture2e("git", *args, chdir: dir)
    raise "git #{args.join(" ")} failed: #{output}" unless status.success?

    output
  end

  def remove = FileUtils.rm_rf(@root)

  private

  def remote = File.join(@root, "remote.git")
  def teammate = File.join(@root, "teammate")
  def current_branch = git(@project, "branch", "--show-current").strip

  def commit_files(dir, files, message)
    identify(dir)
    files.each { |path, content| File.write(File.join(dir, path), content) }
    git(dir, "add", "-A")
    git(dir, "commit", "-q", "-m", message)
    git(dir, "rev-parse", "HEAD").strip
  end

  def identify(dir)
    git(dir, "config", "user.name", "fun-ci test")
    git(dir, "config", "user.email", "test@example.invalid")
  end
end
