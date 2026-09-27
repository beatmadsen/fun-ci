# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/git_project"
require "open3"
require "stringio"
require "fun_ci/cli"

# Real git runs the hooks `fun-ci install-hooks` writes, and each asks fun-ci
# what AT-1.8 and AT-9.13 say (a stand-in `fun-ci` on PATH records its
# arguments and exits as told): a commit starts the pipeline for the commit
# just made, and a push waits for the fast verdict of each commit it sends
# and stops when one isn't 0. What `trigger --background` and `wait` do with
# those arguments is pinned in the acceptance lane.
class TestGitRunsHooks < Minitest::Test
  SHIMS = File.expand_path("../../fixtures/fun_ci_shim", __dir__)

  def setup
    @project = GitProject.create
    @tmp = Dir.mktmpdir("hooks")
    @remote = File.join(@tmp, "remote.git")
    @project.git("init", "-q", "--bare", @remote)
    @project.git("remote", "add", "origin", @remote)
    install_hooks
  end

  def teardown = FileUtils.rm_rf([@project.dir, @tmp])

  def test_a_commit_starts_the_pipeline_for_the_commit_just_made
    commit

    assert_equal ["trigger --background #{head} main"], asked
  end

  def test_a_commit_goes_through
    assert_predicate commit.last, :success?
  end

  def test_a_commit_shows_what_fun_ci_says
    output, = commit

    assert_includes output, "fun-ci was asked: trigger --background #{head} main"
  end

  def test_a_push_waits_for_the_fast_verdict_of_the_commit_it_sends
    commit
    push

    assert_equal "wait #{head} --need fast", asked.last
  end

  def test_a_push_goes_through_when_the_verdict_is_passed
    commit

    assert_predicate push(verdict: 0), :success?
  end

  def test_a_push_stops_when_the_verdict_is_failed
    commit

    refute_predicate push(verdict: 1), :success?
  end

  private

  def head = @project.git("rev-parse", "HEAD").strip
  def asked = File.readlines(File.join(@tmp, "asked"), chomp: true)

  def install_hooks
    io = FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: StringIO.new)
    Dir.chdir(@project.dir) { FunCi::Cli.run(["install-hooks"], io: io) }
  end

  def commit
    @project.write("change.txt", "a change\n")
    @project.git("add", "-A")
    with_hooks("git", "commit", "-q", "-m", "a change")
  end

  def push(verdict: 0) = with_hooks("git", "push", "-q", "origin", "main", verdict: verdict).last

  # A stand-in `fun-ci` on PATH records what it is asked, says so, and exits with `verdict`.
  def with_hooks(*command, verdict: 0)
    env = { "PATH" => "#{SHIMS}:#{ENV.fetch("PATH")}", "FUN_CI_SHIM_ASKED" => File.join(@tmp, "asked"),
            "FUN_CI_SHIM_VERDICT" => verdict.to_s }
    Open3.capture2e(env, *command, chdir: @project.dir)
  end
end
