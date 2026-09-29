# frozen_string_literal: true

require_relative "../trunk/shown"
require_relative "age"

module FunCi
  module Agent
    # How a run's commit stands against the trunk, as `status` and `wait`
    # print it (docs/trunk-conflicts.md, status and wait).
    module TrunkText
      def self.lines(shown)
        check = shown.check
        ["  trunk  #{shown.state.tr("_", " ").ljust(12)} #{detail(shown)}".rstrip,
         *check.files.map { |file| "    #{file}" }]
      end

      def self.detail(shown)
        check = shown.check
        return check.reason if shown.state == "unknown"
        return "" if shown.state == "in_trunk"

        seen = "#{check.ref} #{check.trunk_sha[0, 7]}, fetched #{Age.words(shown.age)}"
        shown.state == "up_to_date" ? seen : "#{seen}, #{check.ahead} ahead, #{check.behind} behind"
      end
      private_class_method :detail
    end
  end
end
