# frozen_string_literal: true

require "optparse"

module FunCi
  module Setup
    # The arguments of `fun-ci init [--everything] [--stack NAME]`.
    module InitOptions
      class Invalid < StandardError; end

      Parsed = Data.define(:everything, :stack)

      def self.parse(args)
        values = { everything: false, stack: nil }
        left = parser(values).parse(args)
        raise Invalid, "takes no #{left.join(" ")}" if left.any?

        Parsed.new(**values)
      rescue OptionParser::ParseError => e
        raise Invalid, e.message
      end

      # Long options only, without OptionParser's own --help and --version.
      def self.parser(values)
        parser = OptionParser.new
        parser.base.long.clear
        parser.on("--everything") { values[:everything] = true }
        parser.on("--stack NAME") { |name| values[:stack] = name }
        parser
      end
      private_class_method :parser
    end
  end
end
