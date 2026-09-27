# frozen_string_literal: true

require "json"
require_relative "findings"
require_relative "problem"

module FunCi
  module Evidence
    # What a project's command printed, as findings: with `format: text`,
    # one excerpt; with `format: json`, the document of `contract/evidence/`, whose fields
    # fun-ci doesn't know are ignored.
    module CommandOutput
      SCHEMA = 1
      FIELDS = { facts: %i[name value], failures: %i[test file line message output],
                 excerpts: %i[title location lines] }.freeze

      def self.text(title, stdout)
        Findings.new(excerpts: [{ title: title, location: "stdout", lines: stdout.lines(chomp: true) }])
      end

      def self.json(stdout)
        document = parse(stdout)
        schema = document.fetch("schema", SCHEMA)
        raise Problem, "printed schema #{schema}, and this fun-ci reads schema #{SCHEMA}" if schema.to_i > SCHEMA

        Findings.new(**FIELDS.to_h { |list, keys| [list, items(document, list, keys)] })
      end

      def self.parse(stdout)
        document = JSON.parse(stdout)
        document.is_a?(Hash) ? document : raise(Problem, "printed JSON that isn't an object")
      rescue JSON::ParserError => e
        raise Problem, "printed JSON that doesn't parse: #{e.message.lines.first.to_s.strip}"
      end

      def self.items(document, list, keys)
        given = document.fetch(list.to_s, [])
        raise Problem, "printed '#{list}' that isn't a list of objects" unless given.is_a?(Array) && given.all?(Hash)

        given.map { |item| keys.to_h { |key| [key, item[key.to_s]] }.compact }
      end
      private_class_method :parse, :items
    end
  end
end
