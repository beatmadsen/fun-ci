# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/git_project"
require_relative "../../../support/descendants"
require "fun_ci/cli"

# AT-9.13 and AT-9.14 with real git: a commit made with the hooks installed
# says how to get its verdict, and a push waits for the fast verdict of what
# it sends. Descendants waits for git, the hooks, and every run they start.
class TestPrePushHook < Minitest::Test
  FUN_CI = File.expand_path("../../../../exe/fun-ci", __dir__)

  def setup
    @project = GitProject.create
    @tmp = Dir.mktmpdir("pre-push")
    @remote = File.join(@tmp, "remote.git")
    @project.git("init", "-q", "--bare", @remote)
    @project.git("remote", "add", "origin", @remote)
    install_hooks
  end

  def teardown = [@project.dir, @tmp].each { |dir| FileUtils.rm_rf(dir) }

  def test_the_commit_says_how_to_get_its_verdict
    commit_with_hooks(fast: "true")

    assert_includes @output, "fun-ci: testing #{head[0, 7]}. Verdict: fun-ci wait #{head[0, 7]} --need all"
  end

  def test_a_push_goes_through_when_the_fast_suite_passes
    commit_with_hooks(fast: "true")

    assert_predicate push, :success?
  end

  def test_a_push_stops_when_the_fast_suite_fails
    commit_with_hooks(fast: "exit 1")

    refute_predicate push, :success?
  end

  def test_a_push_that_stops_says_which_stage_failed
    commit_with_hooks(fast: "echo the fast suite broke; exit 1")
    push

    assert_includes @output, "fast failed:\n  the fast suite broke"
  end

  private

  def head = @project.git("rev-parse", "HEAD").strip

  def install_hooks
    io = FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: StringIO.new)
    Dir.chdir(@project.dir) { FunCi::Cli.run(["install-hooks"], io: io) }
  end

  def commit_with_hooks(fast:)
    @project.write_stage_scripts { |stage| stage == "fast" ? fast : "true" }
    @project.git("add", "-A")
    run_with_hooks("git", "commit", "-q", "-m", "stage scripts")
  end

  def push = run_with_hooks("git", "push", "-q", "origin", "main")

  def run_with_hooks(*command)
    output = File.join(@tmp, "output")
    status = Descendants.spawn(hook_env, *command, chdir: @project.dir, %i[out err] => output).wait_for_all
    @output = File.read(output)
    status
  end

  def hook_env
    shims = File.join(@tmp, "bin").tap { |dir| FileUtils.mkdir_p(dir) }
    File.write(File.join(shims, "fun-ci"), "#!/bin/sh\nexec #{RbConfig.ruby} #{FUN_CI} \"$@\"\n")
    File.chmod(0o755, File.join(shims, "fun-ci"))
    { "PATH" => "#{shims}:#{ENV.fetch("PATH")}", "TMPDIR" => @tmp, "XDG_STATE_HOME" => File.join(@tmp, "state") }
  end
end
