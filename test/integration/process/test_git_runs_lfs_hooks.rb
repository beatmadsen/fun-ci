# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require "open3"
require "fun_ci/setup/lfs_hook"

# In a Git LFS repository, real git runs the hooks fun-ci writes in place of
# git-lfs's, and each runs fun-ci's and then git-lfs's (stand-ins on PATH
# record what each was asked, and git-lfs what it read). A push sends its
# ref list once, and git-lfs gets every byte of it after fun-ci (AT-1.13).
# That install-hooks writes them over git-lfs's is test_hook_writer_lfs.rb's;
# writing them here keeps this slow file off HookWriter's mutants, whose
# covering files must fit mutineer's 10 s cap together.
class TestGitRunsLfsHooks < Minitest::Test
  SHIMS = %w[fun_ci_shim git_lfs_shim].map { |dir| File.expand_path("../../fixtures/#{dir}", __dir__) }

  def setup
    @project = GitProject.create
    @tmp = Dir.mktmpdir("lfs-hooks")
    @remote = File.join(@tmp, "remote.git")
    @project.git("init", "-q", "--bare", @remote)
    @project.git("remote", "add", "origin", @remote)
    %w[post-commit pre-push].each { |type| hook(type) }
  end

  def teardown
    FileUtils.rm_rf(@tmp)
    @project.remove
  end

  def test_a_commit_starts_the_pipeline_for_the_commit_just_made
    commit

    assert_equal ["trigger --background #{head} main"], asked("fun-ci")
  end

  def test_a_commit_runs_git_lfs_s_post_commit
    commit

    assert_equal ["post-commit"], asked("git-lfs")
  end

  def test_a_push_waits_for_the_fast_verdict_of_the_commit_it_sends
    commit
    push

    assert_equal "wait #{head} --need fast", asked("fun-ci").last
  end

  def test_a_push_gives_git_lfs_the_ref_list_git_sent
    commit
    push

    assert_equal "refs/heads/main #{head} refs/heads/main #{"0" * 40}\n", File.read(File.join(@tmp, "lfs-stdin"))
  end

  def test_a_push_runs_git_lfs_s_pre_push_for_the_remote
    commit
    push

    assert_equal "pre-push origin #{@remote}", asked("git-lfs").last
  end

  def test_a_push_fun_ci_stops_sends_nothing_through_git_lfs
    commit
    push(verdict: 1)

    assert_equal ["post-commit"], asked("git-lfs")
  end

  private

  def hook(type) = @project.write(".git/hooks/#{type}", FunCi::Setup::LfsHook.script(type), mode: 0o755)
  def head = @project.git("rev-parse", "HEAD").strip
  def asked(tool) = File.readlines(File.join(@tmp, "#{tool}-asked"), chomp: true)

  def commit
    @project.write("change.txt", "a change\n")
    @project.git("add", "-A")
    with_hooks("git", "commit", "-q", "-m", "a change")
  end

  def push(verdict: 0) = with_hooks("git", "push", "-q", "origin", "main", verdict: verdict)

  def with_hooks(*command, verdict: 0)
    env = { "PATH" => [*SHIMS, ENV.fetch("PATH")].join(":"), "FUN_CI_SHIM_ASKED" => File.join(@tmp, "fun-ci-asked"),
            "FUN_CI_SHIM_VERDICT" => verdict.to_s, "GIT_LFS_SHIM_ASKED" => File.join(@tmp, "git-lfs-asked"),
            "GIT_LFS_SHIM_STDIN" => File.join(@tmp, "lfs-stdin") }
    Open3.capture2e(env, *command, chdir: @project.dir)
  end
end
