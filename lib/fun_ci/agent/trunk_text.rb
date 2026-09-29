# frozen_string_literal: true

require_relative "../trunk/shown"
require_relative "age"

module FunCi
  module Agent
    # How a run's commit stands against the trunk, as `status` and `wait`
    # print it (docs/trunk-conflicts.md, status and wait).
    module TrunkText
      def self.lines(shown)
        ["  trunk  #{shown.state.tr("_", " ").ljust(12)} #{detail(shown)}".rstrip,
         *shown.check.merge.files.map { |file| "    #{file}" }]
      end

      def self.detail(shown)
        merge = shown.check.merge
        return merge.reason if shown.state == "unknown"
        return "" if shown.state == "in_trunk"

        seen = seen(shown)
        shown.state == "up_to_date" ? seen : "#{seen}, #{merge.ahead} ahead, #{merge.behind} behind"
      end

      def self.seen(shown)
        tip = shown.check.tip
        "#{tip.ref} #{tip.sha[0, 7]}, fetched #{Age.words(shown.age)}"
      end
      private_class_method :detail, :seen
    end
  end
end
