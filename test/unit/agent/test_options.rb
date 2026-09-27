# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/agent/options"

class TestOptions < Minitest::Test
  OPTIONS = FunCi::Agent::Options

  def test_should_ask_about_head_for_the_fast_level_by_default
    assert_equal(["HEAD", "fast", false], parse.then { |o| [o.rev, o.need, o.json] })
  end

  def test_should_take_the_revision_given
    assert_equal "abc1234", parse("abc1234").rev
  end

  def test_should_take_the_level_needed
    assert_equal "all", parse("--need", "all").need
  end

  def test_should_refuse_a_level_that_does_not_exist
    error = assert_raises(OPTIONS::Invalid) { parse("--need", "most") }

    assert_equal "unknown level 'most': use build, fast or all", error.message
  end

  def test_should_take_json
    assert parse("--json").json
  end

  def test_should_refuse_an_option_the_command_does_not_take
    assert_raises(OPTIONS::Invalid) { parse("--within", "30") }
  end

  def test_should_read_a_deadline_in_plain_seconds
    assert_equal 30, parse("--within", "30", takes: %i[within]).within
  end

  def test_should_read_a_deadline_in_seconds_or_minutes
    assert_equal [45, 300], [parse("--within", "45s", takes: %i[within]).within,
                             parse("--within", "5m", takes: %i[within]).within]
  end

  def test_should_refuse_a_deadline_it_cannot_read
    assert_raises(OPTIONS::Invalid) { parse("--within", "soon", takes: %i[within]) }
  end

  def test_should_take_following_the_branch
    assert parse("--follow-branch", takes: %i[follow_branch]).follow_branch
  end

  def test_should_list_ten_runs_on_every_branch_by_default
    assert_equal([10, nil], parse(takes: %i[limit branch]).then { |o| [o.limit, o.branch] })
  end

  def test_should_take_a_count_and_a_branch
    options = parse("-n", "5", "--branch", "main", takes: %i[limit branch])

    assert_equal [5, "main"], [options.limit, options.branch]
  end

  def test_should_take_following_as_it_happens
    assert parse("--follow", takes: %i[follow]).follow
  end

  def test_should_take_only_failures
    assert_equal "failures", parse("--only", "failures", takes: %i[only]).only
  end

  def test_should_refuse_to_keep_only_something_it_does_not_know
    error = assert_raises(OPTIONS::Invalid) { parse("--only", "passes", takes: %i[only]) }

    assert_equal "unknown filter 'passes': use failures", error.message
  end

  def test_should_refuse_a_second_revision
    assert_raises(OPTIONS::Invalid) { parse("abc1234", "bcd2345") }
  end

  def test_should_refuse_help_rather_than_print_it_and_exit
    assert_equal(:refused, outcome_of { parse("--help") })
  end

  private

  def outcome_of(&)
    capture_io(&)
    :parsed
  rescue OPTIONS::Invalid
    :refused
  rescue SystemExit
    :exited
  end

  def parse(*args, takes: []) = OPTIONS.parse(args, takes: %i[need json] + takes)
end
