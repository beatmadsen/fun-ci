# frozen_string_literal: true

require_relative "resolver"

module FunCi
  module Trunk
    # What `fun-ci check` says about the trunk (docs/trunk-conflicts.md, fun-ci
    # check): which ref it is, why that one, and how fun-ci keeps it fresh,
    # so the network access never comes as a surprise; or a warning, which
    # never fails the check, when there is none.
    module Description
      WHY = { configured: "trunk: in .fun-ci/config", default: "%s's default branch",
              usual: "the first usual trunk name on %s", local: "a local branch" }.freeze
      NONE = "Trunk: none (trunk: none in .fun-ci/config), so runs check none."
      NOT_FOUND = "Warning: no trunk found, so runs check none; set trunk: in .fun-ci/config"
      UNITS = [[3600, "hour"], [60, "minute"], [1, "second"]].freeze

      # interval: seconds between fetches, nil when fun-ci doesn't fetch.
      def self.lines(setting:, interval:, refs:)
        return [NONE] if setting == "none"

        ref = Resolver.pick(setting, refs)
        return [NOT_FOUND] unless ref

        ["Trunk: #{ref} (#{WHY.fetch(Resolver.why(setting, refs)).sub("%s",
                                                                      ref.remote.to_s)}).#{fetching(ref, interval)}"]
      end

      def self.fetching(ref, interval)
        return "" unless ref.remote
        return " fun-ci doesn't fetch it (trunk_fetch: false)." unless interval

        " fun-ci fetches it in the background, at most every #{every(interval)}; " \
          "set trunk_fetch: false in .fun-ci/config to stop."
      end

      def self.every(seconds)
        size, unit = UNITS.find { |unit_seconds, _| (seconds % unit_seconds).zero? }
        count = seconds / size
        "#{count} #{unit}#{"s" unless count == 1}"
      end
      private_class_method :fetching, :every
    end
  end
end
