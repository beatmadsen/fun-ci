# frozen_string_literal: true

require "optparse"
require_relative "verdict"

module FunCi
  module Agent
    # The arguments of an agent command: at most one revision, and whichever
    # of the switches below the command takes.
    module Options
      class Invalid < StandardError; end

      Parsed = Data.define(:rev, :need, :json, :within, :follow_branch, :limit, :branch)
      DEFAULTS = { need: "fast", json: false, within: nil, follow_branch: false, limit: 10, branch: nil }.freeze
      SWITCHES = { need: ["--need LEVEL"], json: ["--json"], within: ["--within DURATION"],
                   follow_branch: ["--follow-branch"], limit: ["-n N", Integer], branch: ["--branch NAME"] }.freeze
      MULTIPLIERS = { "" => 1, "s" => 1, "m" => 60 }.freeze

      def self.parse(args, takes:)
        values = DEFAULTS.dup
        revs = parser(values, takes).parse(args)
        raise Invalid, "one revision at a time, not #{revs.join(" ")}" if revs.size > 1

        Parsed.new(rev: revs.first || "HEAD", **values)
      rescue OptionParser::ParseError => e
        raise Invalid, e.message
      end

      # Without OptionParser's own --help and --version (long options only), which print and exit.
      def self.parser(values, takes)
        parser = OptionParser.new
        parser.base.long.clear
        takes.each { |key| parser.on(*SWITCHES.fetch(key)) { |value| values[key] = convert(key, value) } }
        parser
      end

      def self.convert(key, value)
        return level(value) if key == :need
        return seconds(value) if key == :within

        value
      end

      def self.level(value)
        return value if Verdict::LEVELS.key?(value)

        raise Invalid, "unknown level '#{value}': use build, fast or all"
      end

      def self.seconds(value)
        match = /\A(\d+)([sm]?)\z/.match(value)
        raise Invalid, "can't read the deadline '#{value}': use 30, 30s or 5m" unless match

        match[1].to_i * MULTIPLIERS.fetch(match[2])
      end
      private_class_method :parser, :convert, :level, :seconds
    end
  end
end
