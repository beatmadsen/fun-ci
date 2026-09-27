# frozen_string_literal: true

module FunCi
  module Evidence
    # What went wrong running an extractor, said as the problem the evidence
    # records against its entry.
    class Problem < StandardError; end
  end
end
