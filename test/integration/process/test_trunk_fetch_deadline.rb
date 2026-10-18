# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_repos"
require_relative "../../support/body_script"
require "fun_ci/trunk/fetch"

# A fetch past its deadline is stopped, its whole group with it. Apart from
# test_trunk_fetch.rb, which never reaches the kill: mutineer runs every file
# that covers a mutant's line within one 10 s cap, and the kill's pure code
# (ProcessTree, GroupKill) must not wait on that file's real fetches.
class TestTrunkFetchDeadline < Minitest::Test
  ORIGIN_MAIN = FunCi::Trunk::Ref.new(remote: "origin", branch: "main")

  def setup = @repos = TrunkRepos.create
  def teardown = @repos.remove

  def test_should_stop_a_fetch_that_runs_past_its_deadline
    pid = hanging_fetch { |started, fetcher| fetcher.finish(started, deadline: 20, timer: ->(*) { false }) }

    # On macOS a group left with only zombies answers EPERM, not ESRCH.
    assert_raises(Errno::ESRCH, Errno::EPERM) { Process.kill(0, -pid) }
  end

  private

  # A fetch whose ssh waits for ever on a FIFO nobody writes; answers its pid.
  def hanging_fetch
    hang_ssh
    fetcher = FunCi::Trunk::Fetch.new(@repos.project, env: {})
    started = fetcher.start(ORIGIN_MAIN)
    yield started, fetcher
    started.pid
  end

  def hang_ssh
    fifo = File.join(@repos.project, "..", "never")
    File.mkfifo(fifo)
    BodyScript.write(File.join(@repos.project, "..", "bin", "hang"), %(read _ < "#{fifo}"))
    @repos.git(@repos.project, "config", "core.sshCommand", File.join(@repos.project, "..", "bin", "hang"))
    @repos.git(@repos.project, "remote", "set-url", "origin", "ssh://example.invalid/repo.git")
  end
end
