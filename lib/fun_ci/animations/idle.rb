# frozen_string_literal: true

module FunCi
  module Animations
    module Idle
      # Gentle starfield -- sparse dots that drift slowly downward
      # Visible but calm: regular cyan (not dim), sparse placement, slow drift

      d = "\e[2;36m"   # dim cyan
      c = "\e[36m"      # cyan
      x = "\e[0m"

      # Each frame drifts the pattern down by ~2 lines, wrapping around.
      # Sparse enough to feel ambient, bright enough to actually see.

      raw_frames = [
        [
          "    #{c}*#{x}                  #{d}.#{x}                         #{c}.#{x}",
          "",
          "         #{d}.#{x}                       #{c}*#{x}",
          "                     #{c}.#{x}                          #{d}.#{x}",
          "",
          "  #{d}.#{x}              #{d}.#{x}                  #{c}*#{x}",
          "",
          "              #{c}.#{x}                                    #{d}.#{x}",
          "                          #{d}.#{x}         #{c}.#{x}",
          "",
          "       #{c}*#{x}                    #{d}.#{x}",
          "                  #{d}.#{x}                       #{c}.#{x}",
          "",
          "   #{d}.#{x}                              #{d}.#{x}",
        ],
        [
          "   #{d}.#{x}                              #{d}.#{x}",
          "    #{c}*#{x}                  #{d}.#{x}                         #{c}.#{x}",
          "",
          "         #{d}.#{x}                       #{c}*#{x}",
          "                     #{c}.#{x}                          #{d}.#{x}",
          "",
          "  #{d}.#{x}              #{d}.#{x}                  #{c}*#{x}",
          "",
          "              #{c}.#{x}                                    #{d}.#{x}",
          "                          #{d}.#{x}         #{c}.#{x}",
          "",
          "       #{c}*#{x}                    #{d}.#{x}",
          "                  #{d}.#{x}                       #{c}.#{x}",
          "",
        ],
        [
          "                  #{d}.#{x}                       #{c}.#{x}",
          "",
          "   #{d}.#{x}                              #{d}.#{x}",
          "    #{c}*#{x}                  #{d}.#{x}                         #{c}.#{x}",
          "",
          "         #{d}.#{x}                       #{c}*#{x}",
          "                     #{c}.#{x}                          #{d}.#{x}",
          "",
          "  #{d}.#{x}              #{d}.#{x}                  #{c}*#{x}",
          "",
          "              #{c}.#{x}                                    #{d}.#{x}",
          "                          #{d}.#{x}         #{c}.#{x}",
          "",
          "       #{c}*#{x}                    #{d}.#{x}",
        ],
        [
          "       #{c}*#{x}                    #{d}.#{x}",
          "                  #{d}.#{x}                       #{c}.#{x}",
          "",
          "   #{d}.#{x}                              #{d}.#{x}",
          "    #{c}*#{x}                  #{d}.#{x}                         #{c}.#{x}",
          "",
          "         #{d}.#{x}                       #{c}*#{x}",
          "                     #{c}.#{x}                          #{d}.#{x}",
          "",
          "  #{d}.#{x}              #{d}.#{x}                  #{c}*#{x}",
          "",
          "              #{c}.#{x}                                    #{d}.#{x}",
          "                          #{d}.#{x}         #{c}.#{x}",
          "",
        ],
        [
          "                          #{d}.#{x}         #{c}.#{x}",
          "",
          "       #{c}*#{x}                    #{d}.#{x}",
          "                  #{d}.#{x}                       #{c}.#{x}",
          "",
          "   #{d}.#{x}                              #{d}.#{x}",
          "    #{c}*#{x}                  #{d}.#{x}                         #{c}.#{x}",
          "",
          "         #{d}.#{x}                       #{c}*#{x}",
          "                     #{c}.#{x}                          #{d}.#{x}",
          "",
          "  #{d}.#{x}              #{d}.#{x}                  #{c}*#{x}",
          "",
          "              #{c}.#{x}                                    #{d}.#{x}",
        ],
        [
          "              #{c}.#{x}                                    #{d}.#{x}",
          "                          #{d}.#{x}         #{c}.#{x}",
          "",
          "       #{c}*#{x}                    #{d}.#{x}",
          "                  #{d}.#{x}                       #{c}.#{x}",
          "",
          "   #{d}.#{x}                              #{d}.#{x}",
          "    #{c}*#{x}                  #{d}.#{x}                         #{c}.#{x}",
          "",
          "         #{d}.#{x}                       #{c}*#{x}",
          "                     #{c}.#{x}                          #{d}.#{x}",
          "",
          "  #{d}.#{x}              #{d}.#{x}                  #{c}*#{x}",
          "",
        ],
      ]

      max = raw_frames.flatten.map { |l| l.gsub(/\e\[[0-9;]*m/, "").length }.max
      raw_frames.each do |frame|
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
