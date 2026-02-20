# frozen_string_literal: true

module FunCi
  module DurationFormatter
    def self.format(seconds)
      if seconds >= 60
        mins = (seconds / 60).to_i
        secs = (seconds % 60).to_i
        "#{mins}m#{secs.to_s.rjust(2, "0")}"
      elsif seconds == seconds.to_i
        "#{seconds.to_i}s"
      else
        "#{format_decimal(seconds)}s"
      end
    end

    def self.format_decimal(value)
      # Show one decimal place, remove trailing zeros
      sprintf("%.1f", value)
    end
    private_class_method :format_decimal
  end
end
