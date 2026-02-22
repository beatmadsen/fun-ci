# frozen_string_literal: true

module FunCi
  module Animations
    module Running
      # A little train chugging along — conveying "work in progress"
      # Loops smoothly: smoke puffs cycle, wheels rotate

      y = "\e[1;33m"  # bold yellow
      w = "\e[1;37m"  # bold white
      c = "\e[1;36m"  # bold cyan
      d = "\e[2;37m"  # dim white (smoke)
      g = "\e[2;32m"  # dim green (track)
      b = "\e[34m"    # blue
      x = "\e[0m"     # reset

      # 6 frames, wheels rotate o/O and smoke puffs drift

      raw_frames = [
        [
          "#{d}    .  .#{x}",
          "#{d}   (    )#{x}",
          "#{d}    '  '#{x}",
          "",
          "    #{y}___#{x}#{c}____#{x}#{y}___#{x}",
          "   #{y}|#{x} #{w}FUN#{x} #{y}|#{c}::::#{y}|#{x}",
          "   #{y}|#{x} #{w}CI!#{x} #{y}|#{c}::::#{y}|#{x}",
          "   #{y}|_____|#{c}____|#{x}",
          "   #{b}(o)  (o)(o)#{x}",
          "",
          "#{g}=========================#{x}",
          "",
          "",
          "",
        ],
        [
          "",
          "#{d}    .  .#{x}",
          "#{d}   ( .  )#{x}",
          "#{d}    '  '#{x}",
          "    #{y}___#{x}#{c}____#{x}#{y}___#{x}",
          "   #{y}|#{x} #{w}FUN#{x} #{y}|#{c}::::#{y}|#{x}",
          "   #{y}|#{x} #{w}CI!#{x} #{y}|#{c}::::#{y}|#{x}",
          "   #{y}|_____|#{c}____|#{x}",
          "   #{b}(O)  (O)(O)#{x}",
          "",
          "#{g}=========================#{x}",
          "",
          "",
          "",
        ],
        [
          "#{d}       .#{x}",
          "#{d}    . .  .#{x}",
          "#{d}   (  .   )#{x}",
          "#{d}    '    '#{x}",
          "    #{y}___#{x}#{c}____#{x}#{y}___#{x}",
          "   #{y}|#{x} #{w}FUN#{x} #{y}|#{c}::::#{y}|#{x}",
          "   #{y}|#{x} #{w}CI!#{x} #{y}|#{c}::::#{y}|#{x}",
          "   #{y}|_____|#{c}____|#{x}",
          "   #{b}(o)  (o)(o)#{x}",
          "",
          "#{g}=========================#{x}",
          "",
          "",
          "",
        ],
        [
          "#{d}          .#{x}",
          "#{d}       . .#{x}",
          "#{d}    .  .#{x}",
          "#{d}   (    )#{x}",
          "    #{y}___#{x}#{c}____#{x}#{y}___#{x}",
          "   #{y}|#{x} #{w}FUN#{x} #{y}|#{c}::::#{y}|#{x}",
          "   #{y}|#{x} #{w}CI!#{x} #{y}|#{c}::::#{y}|#{x}",
          "   #{y}|_____|#{c}____|#{x}",
          "   #{b}(O)  (O)(O)#{x}",
          "",
          "#{g}=========================#{x}",
          "",
          "",
          "",
        ],
        [
          "#{d}             .#{x}",
          "#{d}          .#{x}",
          "#{d}       . .#{x}",
          "#{d}    (. . )#{x}",
          "    #{y}___#{x}#{c}____#{x}#{y}___#{x}",
          "   #{y}|#{x} #{w}FUN#{x} #{y}|#{c}::::#{y}|#{x}",
          "   #{y}|#{x} #{w}CI!#{x} #{y}|#{c}::::#{y}|#{x}",
          "   #{y}|_____|#{c}____|#{x}",
          "   #{b}(o)  (o)(o)#{x}",
          "",
          "#{g}=========================#{x}",
          "",
          "",
          "",
        ],
        [
          "#{d}                .#{x}",
          "#{d}             .#{x}",
          "#{d}          . .#{x}",
          "#{d}    (  .  )#{x}",
          "    #{y}___#{x}#{c}____#{x}#{y}___#{x}",
          "   #{y}|#{x} #{w}FUN#{x} #{y}|#{c}::::#{y}|#{x}",
          "   #{y}|#{x} #{w}CI!#{x} #{y}|#{c}::::#{y}|#{x}",
          "   #{y}|_____|#{c}____|#{x}",
          "   #{b}(O)  (O)(O)#{x}",
          "",
          "#{g}=========================#{x}",
          "",
          "",
          "",
        ],
      ]

      raw_frames.each do |frame|
        max = frame.map { |l| l.gsub(/\e\[[0-9;]*m/, "").length }.max
        frame.map! { |l| l + " " * (max - l.gsub(/\e\[[0-9;]*m/, "").length) }
      end

      DATA = {
        name: "Running",
        fps: 4,
        frames: raw_frames
      }.freeze
    end
  end
end
