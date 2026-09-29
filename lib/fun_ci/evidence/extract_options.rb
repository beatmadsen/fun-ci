# frozen_string_literal: true

require "optparse"

module FunCi
  module Evidence
    # The arguments of `fun-ci extract STAGE --output FILE [--exit N |
    # --timed-out] [--json]`.
    module ExtractOptions
      class Invalid < StandardError; end

      Parsed = Data.define(:stage, :output, :exit_status, :timed_out, :json)
      STAGES = %w[lint build fast slow].freeze
      DEFAULTS = { output: nil, exit_status: 1, timed_out: false, json: false }.freeze

      SWITCHES = { output: ["--output FILE"], exit_status: ["--exit N", Integer], timed_out: ["--timed-out"],
                   json: ["--json"] }.freeze

      def self.parse(args)
        values = DEFAULTS.dup
        stages = parser(values).parse(args)
        raise Invalid, "--output FILE names the saved output to read" unless values[:output]

        Parsed.new(stage: one_stage(stages), **values)
      rescue OptionParser::ParseError => e
        raise Invalid, e.message
      end

      def self.one_stage(stages)
        return stages.first if stages.size == 1 && STAGES.include?(stages.first)

        raise Invalid, "name one stage of #{STAGES.join(", ")}, not #{stages.join(" ")}"
      end

      # A switch without an argument sets its value to true.
      def self.parser(values)
        parser = OptionParser.new
        parser.base.long.clear
        SWITCHES.each { |key, switch| parser.on(*switch) { |value| values[key] = value } }
        parser
      end
      private_class_method :one_stage, :parser
    end
  end
end
