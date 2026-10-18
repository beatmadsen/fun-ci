# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_repos"
require_relative "../../support/body_script"
require_relative "../../support/process_deadline"
require_relative "../../support/lifeline"
require_relative "../../support/fifo"
require "fun_ci/trunk/fetch"

# A fetch past its deadline is stopped, its whole group with it. Apart from
# test_trunk_fetch.rb, which never reaches the kill: mutineer runs every file
# that covers a mutant's line within one 10 s cap, and the kill's pure code
# (ProcessTree, GroupKill) must not wait on that file's real fetches.
class TestTrunkFetchDeadline < Minitest::Test
  include ProcessDeadline

  ORIGIN_MAIN = FunCi::Trunk::Ref.new(remote: "origin", branch: "main")

  def setup = @repos = TrunkRepos.create
  def teardown = @repos.remove

  # git's ssh is orphaned by the kill and may show as running a moment
  # after the fetch returns, so the test waits for it to end.
  def test_should_stop_a_fetch_that_runs_past_its_deadline
    Lifeline.open(File.join(@repos.project, "..")) do |lifeline|
      fetch_past_its_deadline(lifeline)

      assert(within_deadline { lifeline.all_ended? })
    end
  end

  private

  # A fetch whose ssh holds the lifeline and waits for ever on a FIFO nobody
  # writes, finished as its deadline passes.
  def fetch_past_its_deadline(lifeline)
    ssh_started = hang_ssh(lifeline)
    fetcher = FunCi::Trunk::Fetch.new(@repos.project, env: {})
    started = fetcher.start(ORIGIN_MAIN)
    Fifo.read(ssh_started)
    fetcher.finish(started, deadline: 20, timer: ->(*) { false })
  end

  # Answers the FIFO the ssh says on that it has taken hold.
  def hang_ssh(lifeline)
    never, ssh_started = %w[never ssh-started].map { |name| fifo(name) }
    script = File.join(@repos.project, "..", "bin", "hang")
    BodyScript.write(script, %(#{lifeline.hold}; echo > "#{ssh_started}"; read _ < "#{never}"))
    @repos.git(@repos.project, "config", "core.sshCommand", script)
    @repos.git(@repos.project, "remote", "set-url", "origin", "ssh://example.invalid/repo.git")
    ssh_started
  end

  def fifo(name) = File.join(@repos.project, "..", name).tap { |path| File.mkfifo(path) }
end
