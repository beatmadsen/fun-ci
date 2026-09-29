# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/persistence/database"
require "fun_ci/persistence/trunk_fetches"

# How often fun-ci fetches a project's trunk (acceptance-tests.md, AT-11.13, AT-11.18).
class TestTrunkFetches < Minitest::Test
  include DatabaseTestSetup

  NOW = Time.utc(2026, 9, 29, 10)
  INTERVAL = 300
  FAILED = FunCi::Trunk::Fetched.new(error: "fatal: could not read from remote")
  OK = FunCi::Trunk::Fetched.new(error: nil)

  def setup
    setup_test_db
    @fetches = FunCi::Persistence::TrunkFetches.new(@db, "/project")
  end

  def teardown = teardown_test_db

  def test_should_let_the_first_fetch_go
    assert claim(NOW)
  end

  def test_should_hold_back_a_second_fetch_within_the_interval
    claim(NOW)

    refute claim(NOW + INTERVAL - 1)
  end

  def test_should_let_a_fetch_go_once_the_interval_has_passed
    claim(NOW)

    assert claim(NOW + INTERVAL)
  end

  def test_should_wait_twice_as_long_after_a_failed_fetch
    claim(NOW)
    @fetches.finished(FAILED, at: NOW)

    refute claim(NOW + (2 * INTERVAL) - 1)
  end

  def test_should_wait_no_longer_than_an_hour_however_many_fetches_failed
    claim(NOW)
    @fetches.finished(FAILED, at: NOW)
    @fetches.finished(FAILED, at: NOW)
    @fetches.finished(FAILED, at: NOW)
    @fetches.finished(FAILED, at: NOW)

    assert claim(NOW + 3600)
  end

  def test_should_keep_when_the_last_fetch_succeeded
    claim(NOW)
    @fetches.finished(OK, at: NOW)

    assert_equal NOW, @fetches.last.fetched_at
  end

  def test_should_keep_why_the_last_fetch_failed
    claim(NOW)
    @fetches.finished(FAILED, at: NOW)

    assert_equal "fatal: could not read from remote", @fetches.last.error
  end

  def test_should_not_share_the_interval_with_another_project
    claim(NOW)

    assert FunCi::Persistence::TrunkFetches.new(@db, "/elsewhere").claim(now: NOW, interval: INTERVAL)
  end

  private

  def claim(now) = @fetches.claim(now: now, interval: INTERVAL)
end
