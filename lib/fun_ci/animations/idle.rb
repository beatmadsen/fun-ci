# frozen_string_literal: true

module FunCi
  module Animations
    module Idle
      # Gentle breathing dots -- calm ambient animation
      # 14 lines per frame, 6 frames for a smooth loop

      d = "\e[2;32m"   # dim green
      g = "\e[32m"      # green
      b = "\e[2;36m"    # dim cyan
      x = "\e[0m"       # reset

      raw_frames = [
        [
          "#{d}                                                                    #{x}",
          "#{d}       .               .               .               .            #{x}",
          "#{d}                                                                    #{x}",
          "#{d}                  .               .               .                 #{x}",
          "#{d}       .                                                   .        #{x}",
          "#{d}                         .               .                          #{x}",
          "#{d}            .                                         .             #{x}",
          "#{d}                                .                                   #{x}",
          "#{d}       .               .                         .                  #{x}",
          "#{d}                                         .                          #{x}",
          "#{d}            .                                         .             #{x}",
          "#{d}                  .               .                                 #{x}",
          "#{d}       .                                         .                  #{x}",
          "#{d}                                                                    #{x}",
        ],
        [
          "#{d}                                                                    #{x}",
          "#{d}                  .               .               .                 #{x}",
          "#{d}       .                                                   .        #{x}",
          "#{d}                         .               .                          #{x}",
          "#{d}            .                                         .             #{x}",
          "#{g}                                .                                   #{x}",
          "#{d}       .               .                         .                  #{x}",
          "#{d}                                         .                          #{x}",
          "#{d}            .                                         .             #{x}",
          "#{d}                  .               .                                 #{x}",
          "#{d}       .                                         .                  #{x}",
          "#{d}                                                                    #{x}",
          "#{d}       .               .               .               .            #{x}",
          "#{d}                                                                    #{x}",
        ],
        [
          "#{d}                                                                    #{x}",
          "#{d}                         .               .                          #{x}",
          "#{d}            .                                         .             #{x}",
          "#{g}                                .                                   #{x}",
          "#{d}       .               .                         .                  #{x}",
          "#{b}                                         .                          #{x}",
          "#{d}            .                                         .             #{x}",
          "#{d}                  .               .                                 #{x}",
          "#{d}       .                                         .                  #{x}",
          "#{d}                                                                    #{x}",
          "#{d}       .               .               .               .            #{x}",
          "#{d}                                                                    #{x}",
          "#{d}                  .               .               .                 #{x}",
          "#{d}       .                                                   .        #{x}",
        ],
        [
          "#{d}                                                                    #{x}",
          "#{g}                                .                                   #{x}",
          "#{d}       .               .                         .                  #{x}",
          "#{b}                                         .                          #{x}",
          "#{d}            .                                         .             #{x}",
          "#{d}                  .               .                                 #{x}",
          "#{d}       .                                         .                  #{x}",
          "#{d}                                                                    #{x}",
          "#{d}       .               .               .               .            #{x}",
          "#{d}                                                                    #{x}",
          "#{d}                  .               .               .                 #{x}",
          "#{d}       .                                                   .        #{x}",
          "#{d}                         .               .                          #{x}",
          "#{d}            .                                         .             #{x}",
        ],
        [
          "#{d}                                                                    #{x}",
          "#{b}                                         .                          #{x}",
          "#{d}            .                                         .             #{x}",
          "#{d}                  .               .                                 #{x}",
          "#{d}       .                                         .                  #{x}",
          "#{d}                                                                    #{x}",
          "#{d}       .               .               .               .            #{x}",
          "#{d}                                                                    #{x}",
          "#{d}                  .               .               .                 #{x}",
          "#{d}       .                                                   .        #{x}",
          "#{d}                         .               .                          #{x}",
          "#{d}            .                                         .             #{x}",
          "#{g}                                .                                   #{x}",
          "#{d}       .               .                         .                  #{x}",
        ],
        [
          "#{d}                                                                    #{x}",
          "#{d}                  .               .                                 #{x}",
          "#{d}       .                                         .                  #{x}",
          "#{d}                                                                    #{x}",
          "#{d}       .               .               .               .            #{x}",
          "#{d}                                                                    #{x}",
          "#{d}                  .               .               .                 #{x}",
          "#{d}       .                                                   .        #{x}",
          "#{d}                         .               .                          #{x}",
          "#{d}            .                                         .             #{x}",
          "#{g}                                .                                   #{x}",
          "#{d}       .               .                         .                  #{x}",
          "#{b}                                         .                          #{x}",
          "#{d}            .                                         .             #{x}",
        ],
      ]

      # Pad lines so all rows in each frame have equal stripped length
      raw_frames.each do |frame|
        max = frame.map { |l| l.gsub(/\e\[[0-9;]*m/, "").length }.max
        frame.map! { |l| l + " " * (max - l.gsub(/\e\[[0-9;]*m/, "").length) }
      end

      DATA = {
        name: "Idle",
        fps: 4,
        frames: raw_frames
      }.freeze
    end
  end
end
