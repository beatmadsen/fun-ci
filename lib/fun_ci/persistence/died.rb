# frozen_string_literal: true

require "json"
require_relative "../evidence/document"

module FunCi
  module Persistence
    # The evidence kept of a stage or job run whose process died: that it has
    # no result, and why that may be, so it reads apart from a failure of the
    # code. It keeps no end, since when it was found dead says nothing of how
    # long it ran.
    module Died
      def self.evidence(what)
        fact = { name: "ended", extractor: "fun-ci",
                 value: "its process stopped before it said how the #{what} ended (the machine slept or " \
                        "restarted, or something killed it), so this #{what} has no result" }
        JSON.generate(Evidence::Document.new(chosen: [], failures: [], excerpts: [], problems: [], facts: [fact]).to_h)
      end
    end
  end
end
