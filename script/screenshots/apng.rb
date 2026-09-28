# frozen_string_literal: true

require "zlib"

module Screenshots
  # Joins PNG frames of one size and colour type into an animated PNG that
  # loops for ever, each frame shown for the same time. The first frame is
  # also what a viewer without APNG support shows.
  module Apng
    SIGNATURE = "\x89PNG\r\n\x1a\n".b

    def self.write(path, frames, delay_ms:)
      File.binwrite(path, animate(frames.map { |frame| chunks(File.binread(frame)) }, delay_ms))
    end

    def self.animate(pngs, delay_ms)
      header = pngs.first.assoc("IHDR").last
      control = [*header.unpack("NN"), 0, 0, delay_ms, 1000, 0, 0]
      numbers = (0..).each
      body = pngs.each_with_index.map { |png, index| frame(png, index.zero?, control, numbers) }
      [SIGNATURE, chunk("IHDR", header), chunk("acTL", [pngs.size, 0].pack("NN")), *body, chunk("IEND", "")].join
    end

    def self.chunks(png, offset = SIGNATURE.bytesize)
      return [] if offset >= png.bytesize

      length, type = png.unpack("Na4", offset:)
      [[type, png.byteslice(offset + 8, length)]] + chunks(png, offset + length + 12)
    end

    def self.frame(png, first, control, numbers)
      head = chunk("fcTL", [numbers.next, *control].pack("N5n2C2"))
      return head + images(png).map { |data| chunk("IDAT", data) }.join if first

      head + images(png).map { |data| chunk("fdAT", [numbers.next].pack("N") + data) }.join
    end

    def self.images(png) = png.filter_map { |type, data| data if type == "IDAT" }

    def self.chunk(type, data)
      body = type.b + data.b
      [data.bytesize].pack("N") + body + [Zlib.crc32(body)].pack("N")
    end
  end
end
