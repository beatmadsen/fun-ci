# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../script/screenshots/apng"

# How script/readme_screenshots.rb joins PNG frames into an animated PNG
# (the APNG chunks: acTL, fcTL, fdAT), checked on the chunks it writes.
class TestApng < Minitest::Test
  HEADER = [800, 384, 8, 2, 0, 0, 0].pack("NNC5")

  def test_should_announce_every_frame_and_loop_for_ever
    assert_equal [3, 0], chunk(animation, "acTL").unpack("NN")
  end

  def test_should_number_frame_controls_and_frame_data_in_one_sequence_from_zero
    numbers = animation_chunks.filter_map { |type, data| data.unpack1("N") if %w[fcTL fdAT].include?(type) }

    assert_equal [0, 1, 2, 3, 4], numbers
  end

  def test_should_keep_the_first_frame_as_the_image_a_still_viewer_shows
    assert_equal "first", chunk(animation, "IDAT")
  end

  def test_should_carry_a_later_frame_after_its_sequence_number
    assert_equal "third", animation_chunks.last(2).first.last.byteslice(4..)
  end

  def test_should_show_each_frame_for_the_delay_at_the_frames_size
    assert_equal [800, 384, 0, 0, 200, 1000, 0, 0], chunk(animation, "fcTL").unpack("x4N4n2C2")
  end

  def test_should_give_every_chunk_the_checksum_of_its_type_and_data
    wrong = crcs(animation).reject { |stored, computed| stored == computed }

    assert_empty wrong
  end

  private

  def png(image) = [["IHDR", HEADER], ["IDAT", image], ["IEND", ""]]

  def animation = Screenshots::Apng.animate([png("first"), png("second"), png("third")], 200)

  def animation_chunks = Screenshots::Apng.chunks(animation)

  def chunk(bytes, type) = Screenshots::Apng.chunks(bytes).assoc(type).last

  def crcs(bytes, offset = Screenshots::Apng::SIGNATURE.bytesize)
    return [] if offset >= bytes.bytesize

    length = bytes.unpack1("N", offset:)
    stored = bytes.unpack1("N", offset: offset + 8 + length)
    [[stored, Zlib.crc32(bytes.byteslice(offset + 4, length + 4))]] + crcs(bytes, offset + length + 12)
  end
end
