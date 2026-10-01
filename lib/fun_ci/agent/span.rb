# frozen_string_literal: true

module FunCi
  module Agent
    # How long a daily or weekly job's run took, in the words the console uses
    # for it: `42s`, `50m`, `3h12m`, `1d`, `1d2h`.
    module Span
      def self.words(seconds)
        whole = seconds.round
        return "#{whole}s" if whole < 60
        return "#{whole / 60}m" if whole < 3600
        return joined(whole / 3600, "h", (whole % 3600 / 60).to_s.rjust(2, "0"), "m") if whole < 86_400

        joined(whole / 86_400, "d", (whole % 86_400 / 3600).to_s, "h")
      end

      # `3h12m`, or `3h` when there is nothing of the smaller unit.
      def self.joined(big, big_unit, small, small_unit)
        small.to_i.zero? ? "#{big}#{big_unit}" : "#{big}#{big_unit}#{small}#{small_unit}"
      end
      private_class_method :joined
    end
  end
end
