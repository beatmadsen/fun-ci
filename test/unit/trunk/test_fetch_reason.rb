# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/trunk/fetch"

# Why a fetch of the trunk failed, from what git printed (architecture.md, Checking against the trunk).
class TestFetchReason < Minitest::Test
  def test_should_give_git_s_fatal_line
    assert_equal "fatal: could not read from remote", reason("warning: slow\nfatal: could not read from remote\n")
  end

  def test_should_give_the_first_line_when_none_is_fatal
    assert_equal "ssh: connect to host example.invalid: timed out",
                 reason("\nssh: connect to host example.invalid: timed out\n")
  end

  def test_should_say_the_fetch_failed_when_git_printed_nothing
    assert_equal "git fetch failed", reason("")
  end

  private

  def reason(output) = FunCi::Trunk::Fetch.reason(output)
end
