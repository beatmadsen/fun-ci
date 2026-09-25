# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../support/git_project"
require "fun_ci/cli"

# AT-1.8: the hook that runs a pipeline in the background is post-commit, so
# the commit it tests is the one just made. The commit runs with `fun-ci` on
# PATH, and with one end of a pipe as fd 3, which git, the hook, the trigger
# and its background fork all inherit, so reading that pipe to its end waits
# until every one of them has finished.
class TestPostCommitHook < Minitest::Test
  FUN_CI = File.expand_path("../../../../exe/fun-ci", __dir__)

  def setup
    @project = GitProject.create
    @tmp = Dir.mktmpdir("post-commit")
    @project.write_stage_scripts { |stage| stage == "slow" ? "git rev-parse HEAD > #{tested}" : "true" }
    @project.commit("stage scripts")
    install_hooks
    @exit_status = commit_with_hooks
  end

  def teardown = [@project.dir, @tmp].each { |dir| FileUtils.rm_rf(dir) }

  def test_the_commit_goes_through
    assert_predicate @exit_status, :success?
  end

  def test_the_pipeline_tests_the_commit_just_made
    assert_equal @project.git("rev-parse", "HEAD"), File.read(tested)
  end

  private

  def tested = File.join(@tmp, "tested")

  def install_hooks
    io = FunCi::Pipeline::Io.new(stdout: StringIO.new, stderr: StringIO.new)
    Dir.chdir(@project.dir) { FunCi::Cli.run(["install-hooks"], io: io) }
  end

  def commit_with_hooks
    @project.write("change.txt", "a change\n")
    @project.git("add", "-A")
    all_gone, held = IO.pipe
    pid = Process.spawn(hook_env, "git", "commit", "-q", "-m", "a change", chdir: @project.dir,
                                                                           3 => held, %i[out err] => File::NULL)
    held.close
    all_gone.read.then { Process.wait2(pid).last }
  end

  def hook_env
    shims = File.join(@tmp, "bin").tap { |dir| FileUtils.mkdir_p(dir) }
    File.write(File.join(shims, "fun-ci"), "#!/bin/sh\nexec #{RbConfig.ruby} #{FUN_CI} \"$@\"\n")
    File.chmod(0o755, File.join(shims, "fun-ci"))
    { "PATH" => "#{shims}:#{ENV.fetch("PATH")}", "TMPDIR" => @tmp }
  end
end
