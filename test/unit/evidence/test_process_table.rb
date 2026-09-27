# frozen_string_literal: true

require_relative "../../test_helper"
require "fun_ci/evidence/process_table"

# The processes `ps` lists, read from listings recorded on each kind of ps
# (test/fixtures/ps/).
class TestProcessTable < Minitest::Test
  TABLE = FunCi::Evidence::ProcessTable
  ROW = TABLE::Row
  FIXTURES = File.expand_path("../../fixtures/ps", __dir__)

  def test_should_read_a_bsd_listing
    assert_equal ROW.new(pid: 33_860, ppid: 33_858, pgid: 33_656, seconds: 1, command: "sleep 7"), rows("bsd.txt").last
  end

  def test_should_read_an_elapsed_time_with_days
    assert_equal 173_652, rows("bsd.txt").first.seconds
  end

  def test_should_read_a_procps_listing
    assert_equal ROW.new(pid: 17, ppid: 15, pgid: 1, seconds: 1, command: "sleep 7"), rows("procps.txt")[2]
  end

  def test_should_read_a_busybox_listing_past_its_header
    assert_equal ROW.new(pid: 9, ppid: 7, pgid: 1, seconds: 2, command: "sleep 7"), rows("busybox.txt").last
  end

  def test_should_skip_a_listing_s_header
    assert_equal 1, rows("busybox.txt").first.pid
  end

  def test_should_read_an_elapsed_time_in_hours
    assert_equal 3723, TABLE.parse("  5  1  5  01:02:03 make\n").first.seconds
  end

  private

  def rows(name) = TABLE.parse(File.read(File.join(FIXTURES, name)))
end
