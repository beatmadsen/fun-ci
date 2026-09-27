# frozen_string_literal: true

# Output a stage could print, made at random from a seeded Random so a failure
# can be run again: bytes that aren't UTF-8, colour codes, JSON-looking and
# log-looking pieces, and sometimes no newline at the end. Labelled UTF-8, as
# ProcessRunner labels what a stage prints, whether or not it is.
class ArbitraryOutput
  PIECES = ["\e[31m", "\e[0m", "\n", "\r\n", "{", "}", '"level":"error"', '"msg":', "ERROR", "Failures:", "  1) ",
            "Finished in", "\xFF\xFE".b, "é", "\t", " ", "x", "42", "rspec ./", "--- FAIL:"].freeze

  def initialize(random)
    @random = random
  end

  def text(pieces = 200)
    Array.new(pieces) { piece }.join.b.force_encoding(Encoding::UTF_8)
  end

  def piece = @random.rand < 0.1 ? @random.bytes(3) : PIECES.sample(random: @random).b
  def word(length) = Array.new(length) { [*"a".."z", *"A".."Z", *"0".."9", "-", "_"].sample(random: @random) }.join
end
