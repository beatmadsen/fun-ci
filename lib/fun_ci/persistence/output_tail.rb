# frozen_string_literal: true

module FunCi
  module Persistence
    # The end of what a stage printed, as fun-ci keeps it for a stage that
    # failed (acceptance-tests.md, AT-9.5): the last 200 lines, at most 64 KB,
    # colour codes stripped and bytes that aren't UTF-8 replaced. `mask`
    # sees the last lines before they are cut to size, so no cut splits a
    # secret it would have masked.
    module OutputTail
      LINES = 200
      BYTES = 65_536
      COLOUR = /\e\[[0-9;?]*[A-Za-z]/

      def self.of(output, mask: :itself.to_proc)
        text = output.dup.force_encoding(Encoding::UTF_8).scrub("?").gsub(COLOUR, "")
        last_bytes(mask.call(text.lines.last(LINES).join))
      end

      def self.last_bytes(text) = text.byteslice([text.bytesize - BYTES, 0].max..).scrub("")
      private_class_method :last_bytes
    end
  end
end
