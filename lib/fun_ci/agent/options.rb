# frozen_string_literal: true

require "optparse"
require_relative "verdict"

module FunCi
  module Agent
    # The arguments of an agent command: at most one revision, then, for a
    # command that takes :stage, a stage's name, and whichever of the switches
    # below the command takes.
    module Options
      class Invalid < StandardError; end

      Parsed = Data.define(:rev, :stage, :need, :json, :within, :follow_branch, :limit, :branch, :follow, :only, :raw)
      DEFAULTS = { need: "fast", json: false, within: nil, follow_branch: false, limit: 10, branch: nil,
                   follow: false, only: nil, raw: false }.freeze
      SWITCHES = { need: ["--need LEVEL"], json: ["--json"], within: ["--within DURATION"], raw: ["--raw"],
                   follow_branch: ["--follow-branch"], limit: ["-n N", Integer], branch: ["--branch NAME"],
                   follow: ["--follow"], only: ["--only KIND"] }.freeze
      FILTERS = %w[failures].freeze
      MULTIPLIERS = { "" => 1, "s" => 1, "m" => 60 }.freeze

      STAGES = %w[lint build fast slow].freeze

      def self.parse(args, takes:)
        values = DEFAULTS.dup
        revs = parser(values, takes).parse(args)
        stage = takes.include?(:stage) && STAGES.include?(revs.last) ? revs.pop : nil
        raise Invalid, "one revision at a time, not #{revs.join(" ")}" if revs.size > 1

        Parsed.new(rev: revs.first || "HEAD", stage: stage, **values)
      rescue OptionParser::ParseError => e
        raise Invalid, e.message
      end

      # Without OptionParser's own --help and --version (long options only), which print and exit.
      def self.parser(values, takes)
        parser = OptionParser.new
        parser.base.long.clear
        (takes & SWITCHES.keys).each do |key|
          parser.on(*SWITCHES.fetch(key)) { |value| values[key] = convert(key, value) }
        end
        parser
      end

      def self.convert(key, value)
        return level(value) if key == :need
        return seconds(value) if key == :within
        return filter(value) if key == :only

        value
      end

      def self.level(value)
        return value if Verdict::LEVELS.key?(value)

        raise Invalid, "unknown level '#{value}': use build, fast or all"
      end

      def self.filter(value)
        return value if FILTERS.include?(value)

        raise Invalid, "unknown filter '#{value}': use #{FILTERS.join(", ")}"
      end

      def self.seconds(value)
        match = /\A(\d+)([sm]?)\z/.match(value)
        raise Invalid, "can't read the deadline '#{value}': use 30, 30s or 5m" unless match

        match[1].to_i * MULTIPLIERS.fetch(match[2])
      end
      private_class_method :parser, :convert, :level, :filter, :seconds
    end
  end
end
