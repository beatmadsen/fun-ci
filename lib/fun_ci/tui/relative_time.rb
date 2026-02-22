# frozen_string_literal: true

require "time"

module FunCi
  module Tui
    module RelativeTime
      def self.format(iso_timestamp, now: Time.now)
        elapsed = now - Time.parse(iso_timestamp)
        seconds = elapsed.to_i

        if seconds < 60
          "just now"
        elsif seconds < 3600
          "#{seconds / 60}m ago"
        else
          "#{seconds / 3600}h ago"
        end
      end
    end
  end
end
