# frozen_string_literal: true

require_relative "../test_helper"
require "stringio"
require "fun_ci/persistence/write_trouble"

# AT-8.2, AT-8.4: a refused write is skipped, and the developer told once.
class TestWriteTrouble < Minitest::Test
  def setup
    @out = StringIO.new
    @trouble = FunCi::Persistence::WriteTrouble.new(@out, "/data/db.sqlite3")
  end

  def test_should_give_back_the_block_s_value_when_the_write_succeeds
    assert_equal(42, @trouble.guard { 42 })
  end

  def test_should_give_back_nothing_when_the_database_refuses_the_write
    assert_nil(@trouble.guard { raise SQLite3::BusyException })
  end

  def test_should_say_that_triggering_again_records_a_run_a_busy_database_kept_out
    @trouble.guard { raise SQLite3::BusyException }

    assert_includes @out.string, "the database stayed busy. Your stages still ran. Trigger it again to record it."
  end

  def test_should_name_the_database_a_full_disk_kept_a_write_out_of
    @trouble.guard { raise SQLite3::FullException }

    assert_includes @out.string, "can't write to the database at /data/db.sqlite3. Check the disk has space."
  end

  def test_should_count_a_read_only_database_as_unwritable
    @trouble.guard { raise SQLite3::ReadOnlyException }

    assert_includes @out.string, "can't write to the database"
  end

  def test_should_say_it_only_once_however_many_writes_are_refused
    3.times { @trouble.guard { raise SQLite3::BusyException } }

    assert_equal 1, @out.string.lines.size
  end

  def test_should_let_any_other_error_through
    assert_raises(SQLite3::SQLException) { @trouble.guard { raise SQLite3::SQLException } }
  end
end
