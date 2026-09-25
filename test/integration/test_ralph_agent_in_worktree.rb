# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "open3"
require "tmpdir"

# Drives ralph/agent-in-worktree.sh against a throwaway repository with a fake
# agent and a fake gate. Real git, temp directories only.
class TestRalphAgentInWorktree < Minitest::Test
  SCRIPT = File.expand_path("../../ralph/agent-in-worktree.sh", __dir__)
  GIT_ISOLATION = { "GIT_CONFIG_GLOBAL" => File::NULL, "GIT_CONFIG_NOSYSTEM" => "1" }.freeze
  ONE_COMMIT = "sh -c 'echo x > a.txt && git add a.txt && git commit -qm \"AT-1.1: add a\"'"

  def setup
    @tmp = Dir.mktmpdir("ralph-test")
    @repo = File.join(@tmp, "proj")
    git_init
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def test_lands_a_single_green_commit_on_the_integration_branch
    _, status = iterate(agent: ONE_COMMIT)

    assert status.success?
    assert_equal "AT-1.1: add a", git("log", "-1", "--format=%s")
    assert_match(/\A1\tlanded\t\h+\tAT-1\.1: add a\n\z/, log)
  end

  def test_rejects_an_iteration_whose_gate_is_red_and_keeps_its_branch
    _, status = iterate(agent: ONE_COMMIT, gate: "false")

    refute status.success?
    assert_equal "init", git("log", "-1", "--format=%s")
    assert_includes git("branch", "--list", "ralph/rejected/*"), "ralph/rejected/iter-1"
    assert_match(/rejected\t\h+\tgate red/, log)
  end

  def test_rejects_an_iteration_with_more_than_one_commit
    two = "sh -c '#{ONE_COMMIT.delete_prefix("sh -c '").delete_suffix("'")} && git commit -q --allow-empty -m b'"

    _, status = iterate(agent: two)

    refute status.success?
    assert_equal "init", git("log", "-1", "--format=%s")
    assert_match(/expected exactly 1 commit, got 2/, log)
  end

  def test_rejects_an_iteration_that_commits_nothing
    _, status = iterate(agent: "true")

    refute status.success?
    assert_match(/expected exactly 1 commit, got 0/, log)
  end

  def test_the_agent_runs_inside_the_worktree_not_the_main_checkout
    iterate(agent: "sh -c 'pwd > where.txt && git add where.txt && git commit -qm where'")

    assert_equal File.join(@tmp, "wt", "iter-1"), File.read(File.join(@repo, "where.txt")).strip
  end

  def test_numbers_iterations_consecutively_and_cleans_up_worktrees
    iterate(agent: ONE_COMMIT)
    iterate(agent: "sh -c 'echo y > b.txt && git add b.txt && git commit -qm \"AT-1.2: add b\"'")

    assert_equal(%w[1 2], log.lines.map { |l| l.split("\t").first })
    assert_equal 1, git("worktree", "list").lines.count
  end

  def test_an_agent_that_fails_is_rejected_with_its_exit_status
    iterate(agent: "exit 1")

    assert_match(/rejected\t\h+\tagent exited 1\n/, log)
  end

  # What ralph -t does: SIGTERM to the whole process group.
  def test_an_iteration_whose_group_is_killed_is_rejected_and_cleaned_up
    iterate(agent: "sh -c 'kill -TERM 0'")

    assert_killed_iteration_cleaned_up
  end

  # The wrapper leads its group (pgroup: true), so its pid is the pgid. A
  # SIGTERM that reaches it outside a wait kills bash unless it traps it.
  def test_a_wrapper_killed_directly_still_rejects_and_cleans_up
    iterate(agent: %(sh -c 'kill -TERM "$(ps -o pgid= -p $$ | tr -d " ")"'))

    assert_killed_iteration_cleaned_up
  end

  private

  def assert_killed_iteration_cleaned_up
    assert_equal 1, git("worktree", "list").lines.count
    assert_includes git("branch", "--list", "ralph/rejected/*"), "ralph/rejected/iter-1"
    assert_match(/rejected\t\h+\tkilled by signal/, log)
  end

  def iterate(agent:, gate: "true")
    env = GIT_ISOLATION.merge("RALPH_AGENT" => agent, "RALPH_GATE" => gate, "RALPH_DIR" => File.join(@tmp, "wt"))
    Open3.capture2e(env, SCRIPT, chdir: @repo, stdin_data: "prompt", pgroup: true)
  end

  def log
    File.read(File.join(@repo, "ralph", "log.tsv"))
  end

  def git_init
    FileUtils.mkdir_p(File.join(@repo, "ralph"))
    File.write(File.join(@repo, ".gitignore"), "ralph/log.tsv\n")
    git("init", "-q", "-b", "main")
    git("-c", "user.name=t", "-c", "user.email=t@t", "add", ".")
    git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "init")
    git("config", "user.name", "t")
    git("config", "user.email", "t@t")
  end

  def git(*)
    out, status = Open3.capture2e(GIT_ISOLATION, "git", *, chdir: @repo)
    raise out unless status.success?

    out.strip
  end
end
