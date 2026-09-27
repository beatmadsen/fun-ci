# frozen_string_literal: true

module FunCi
  module Evidence
    # What an extractor found: facts ({ name:, value: }), failures ({ test:,
    # file:, line:, message:, output: }) and excerpts ({ title:, location:,
    # lines:, truncated: }).
    Findings = Data.define(:facts, :failures, :excerpts)

    class Findings
      def initialize(facts: [], failures: [], excerpts: []) = super
    end
  end
end
