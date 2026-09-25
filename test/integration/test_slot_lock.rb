# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/pipeline/slot_lock"
require "tmpdir"

class TestSlotLock < Minitest::Test
  def setup
    @dir = Dir.mktmpdir("slot-lock")
    @path = File.join(@dir, "slot-0.lock")
  end

  def teardown
    @holder&.close
    FileUtils.rm_rf(@dir)
  end

  def test_should_see_a_lock_another_descriptor_holds
    hold

    assert FunCi::Pipeline::SlotLock.held?(@path)
  end

  def test_should_see_a_lock_nobody_holds_as_free
    File.write(@path, "12345")

    refute FunCi::Pipeline::SlotLock.held?(@path)
  end

  def test_should_see_a_missing_lock_as_free
    refute FunCi::Pipeline::SlotLock.held?(@path)
  end

  def test_should_not_keep_the_lock_it_checked
    File.write(@path, "")
    FunCi::Pipeline::SlotLock.held?(@path)

    assert(File.open(@path) { |lock| lock.flock(File::LOCK_EX | File::LOCK_NB) })
  end

  private

  def hold
    @holder = File.new(@path, File::RDWR | File::CREAT)
    @holder.flock(File::LOCK_EX)
  end
end
