# frozen_string_literal: true

module FunCi
  module Evidence
    # Masks secrets in text before fun-ci keeps it (why.md, "Masking
    # secrets"): the values of the stage's secret-named variables, well-known
    # token shapes, and a project's own patterns. A best effort, not a
    # guarantee. Given the environment as a hash; never reads ENV.
    class Masking
      SECRET_NAME = /TOKEN|SECRET|PASSWORD|PASSWD|API_KEY|PRIVATE_KEY|CREDENTIAL/
      SHORTEST = 8
      SHAPES = [
        /-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----/m,
        /\bgh[pousr]_[A-Za-z0-9]{36,}/,
        /\b(?:AKIA|ASIA)[0-9A-Z]{16}\b/,
        /\bxox[abpors]-[A-Za-z0-9-]{10,}/,
        /(?<=Authorization: ).+/i
      ].freeze

      def initialize(environment, patterns: [])
        @secrets = secrets(environment)
        @patterns = SHAPES + patterns
      end

      def mask(text)
        masked = @secrets.reduce(text) { |current, (name, value)| current.gsub(value, "[masked:#{name}]") }
        @patterns.reduce(masked) { |current, pattern| current.gsub(pattern, "[masked]") }
      end

      private

      # Longest first, so a value that contains another is masked whole.
      def secrets(environment)
        environment.select { |name, value| name.match?(SECRET_NAME) && value.to_s.length >= SHORTEST }
                   .sort_by { |_name, value| -value.length }
      end
    end
  end
end
