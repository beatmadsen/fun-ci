# frozen_string_literal: true

require_relative "../test_helper"
require "tmpdir"
require "fun_ci/persistence/raw_outputs"

# The raw output of each failed stage, kept as a compressed file per stage
# beside the database (architecture.md, "Evidence of a failed stage").
class TestRawOutputs < Minitest::Test
  TEXT = "line of output\n" * 1000

  def setup
    @dir = Dir.mktmpdir
    @raw = FunCi::Persistence::RawOutputs.new(File.join(@dir, "raw"))
  end

  def teardown = FileUtils.remove_entry(@dir)

  def test_should_read_back_what_it_kept
    @raw.write(7, TEXT)

    assert_equal TEXT, @raw.read(7)
  end

  def test_should_keep_it_compressed
    @raw.write(7, TEXT)

    assert_operator File.size(File.join(@dir, "raw", "7.gz")), :<, TEXT.bytesize / 10
  end

  def test_should_say_how_many_bytes_it_kept
    @raw.write(7, TEXT)

    assert_equal 15_000, @raw.bytes(7)
  end

  def test_should_answer_nothing_for_a_stage_it_kept_nothing_of
    assert_equal [nil, nil], [@raw.read(8), @raw.bytes(8)]
  end

  def test_should_delete_what_it_kept_of_the_stages_named
    @raw.write(7, TEXT)
    @raw.write(8, TEXT)
    @raw.delete([7])

    assert_equal [nil, 15_000], [@raw.bytes(7), @raw.bytes(8)]
  end

  def test_should_delete_what_it_kept_of_stages_that_no_longer_exist
    @raw.write(7, TEXT)
    @raw.write(8, TEXT)
    @raw.keep_only([8, 9])

    assert_equal [nil, 15_000], [@raw.bytes(7), @raw.bytes(8)]
  end
end
