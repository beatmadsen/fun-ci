# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trunk_repos"
require_relative "../../support/body_script"
require "fun_ci/trunk/fetch"

# fun-ci fetches the trunk into a ref of its own, touching none of the
# developer's, and never waits on a prompt (acceptance-tests.md, AT-11.11, 11.12, 11.16, 11.17).
class TestTrunkFetch < Minitest::Test
  ORIGIN_MAIN = FunCi::Trunk::Ref.new(remote: "origin", branch: "main")

  def setup = @repos = TrunkRepos.create
  def teardown = @repos.remove

  def test_should_fetch_the_remote_s_trunk_into_fun_ci_s_own_ref
    upstream = @repos.upstream("a.txt" => "a\n")
    fetch

    assert_equal upstream, rev("refs/fun-ci/trunk/origin/main")
  end

  def test_should_leave_the_developer_s_remote_tracking_ref_as_it_was
    before = rev("refs/remotes/origin/main")
    @repos.upstream("a.txt" => "a\n")
    fetch

    assert_equal before, rev("refs/remotes/origin/main")
  end

  def test_should_write_no_fetch_head
    fetch

    refute File.exist?(File.join(@repos.project, ".git", "FETCH_HEAD"))
  end

  def test_should_say_why_a_fetch_failed
    @repos.git(@repos.project, "remote", "set-url", "origin", File.join(@repos.project, "no-such-remote.git"))

    assert_match(/no-such-remote/, fetch.error)
  end

  def test_should_ask_ssh_never_to_prompt
    bin = File.join(@repos.project, "..", "bin")
    BodyScript.write(File.join(bin, "ssh"), %(echo "$@" > "#{bin}/ssh-args"; exit 255))
    @repos.git(@repos.project, "remote", "set-url", "origin", "ssh://example.invalid/repo.git")
    fetch(env: { "PATH" => "#{bin}:#{ENV.fetch("PATH")}" })

    assert_includes File.read(File.join(bin, "ssh-args")), "BatchMode=yes"
  end

  def test_should_stop_a_fetch_that_runs_past_its_deadline
    pid = hanging_fetch { |started, fetcher| fetcher.finish(started, deadline: 20, timer: ->(*) { false }) }

    assert_raises(Errno::ESRCH) { Process.kill(0, -pid) }
  end

  private

  def fetch(env: {})
    fetcher = FunCi::Trunk::Fetch.new(@repos.project, env: env)
    fetcher.finish(fetcher.start(ORIGIN_MAIN), deadline: 20)
  end

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

  def rev(ref) = @repos.git(@repos.project, "rev-parse", ref).strip
end
