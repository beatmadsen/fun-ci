# frozen_string_literal: true

module FunCi
  module Animations
    module Explosion
      # Failure explosion animation — expanding fireball with debris
      # Run: ruby exe/animation-player animations/explosion.rb

      r = "\e[1;31m"  # bold red
      o = "\e[38;5;208m" # orange
      y = "\e[1;33m"  # bold yellow
      w = "\e[1;37m"  # bold white
      d = "\e[2;31m"  # dim red
      k = "\e[38;5;52m" # dark red
      x = "\e[0m"     # reset

      raw_frames = [
          # Frame 1 — spark
          [
            "",
            "",
            "",
            "",
            "             #{w}*#{x}",
            "",
            "",
            "",
            "",
            "",
          ],
          # Frame 2 — ignition
          [
            "",
            "",
            "",
            "            #{y}\\|/#{x}",
            "            #{w}-#{r}*#{w}-#{x}",
            "            #{y}/|\\#{x}",
            "",
            "",
            "",
            "",
          ],
          # Frame 3 — small burst
          [
            "",
            "",
            "           #{o}. * .#{x}",
            "          #{y}*#{r}(#)#{y}*#{x}",
            "         #{r}(#{y}*#{w}@@@#{y}*#{r})#{x}",
            "          #{y}*#{r}(#)#{y}*#{x}",
            "           #{o}' * '#{x}",
            "",
            "",
            "",
          ],
          # Frame 4 — expanding fireball
          [
            "",
            "          #{o}*  .  *#{x}",
            "        #{y}.#{r}* #{o}( ) #{r}*#{y}.#{x}",
            "       #{r}(#{y}*#{w} @@@@@ #{y}*#{r})#{x}",
            "      #{r}(#{o}*#{w}@@@#{y}X#{w}@@@#{o}*#{r})#{x}",
            "       #{r}(#{y}*#{w} @@@@@ #{y}*#{r})#{x}",
            "        #{y}'#{r}* #{o}( ) #{r}*#{y}'#{x}",
            "          #{o}*  '  *#{x}",
            "",
            "",
          ],
          # Frame 5 — full explosion
          [
            "        #{d}. #{o}*   *  .#{d} .#{x}",
            "      #{o}*  #{y}.#{r}*     *#{y}.  #{o}*#{x}",
            "    #{y}. #{r}*#{o}(#{w} @@@@@@@@ #{o})#{r}*#{y} .#{x}",
            "   #{r}( #{y}*#{w}@@@@#{y}BOOM#{w}@@@@#{y}* #{r})#{x}",
            "  #{r}(#{o}*#{w}@@@@@@@#{y}X#{w}@@@@@@@#{o}*#{r})#{x}",
            "   #{r}( #{y}*#{w}@@@@@@@@@@@#{y}* #{r})#{x}",
            "    #{y}' #{r}*#{o}(#{w} @@@@@@@@ #{o})#{r}*#{y} '#{x}",
            "      #{o}*  #{y}'#{r}*     *#{y}'  #{o}*#{x}",
            "        #{d}' #{o}*   *  '#{d} '#{x}",
            "",
          ],
          # Frame 6 — debris flying out
          [
            "    #{d}.#{x}    #{o}*#{x}         #{o}*#{x}   #{d}.#{x}",
            "       #{o}. #{y}*#{x}  #{d}.  .#{x}  #{y}* #{o}.#{x}",
            "     #{y}*#{x}  #{r}*#{o}( #{d}::::: #{o})#{r}*#{x}  #{y}*#{x}",
            "    #{r}(#{x} #{y}*#{x} #{d}::#w}@@#{y}X#{w}@@#{d}::#{x} #{y}*#{x} #{r})#{x}",
            "   #{o}*#{x}  #{d}:::#{w}@@@@@@@#{d}:::#{x}  #{o}*#{x}",
            "    #{r}(#{x} #{y}*#{x} #{d}::#{w}@@@@@#{d}::#{x} #{y}*#{x} #{r})#{x}",
            "     #{y}*#{x}  #{r}*#{o}( #{d}::::: #{o})#{r}*#{x}  #{y}*#{x}",
            "       #{o}' #{y}*#{x}  #{d}'  '#{x}  #{y}* #{o}'#{x}",
            "    #{d}'#{x}    #{o}*#{x}         #{o}*#{x}   #{d}'#{x}",
            "  #{d}.#{x}         #{d}. .#{x}         #{d}.#{x}",
          ],
          # Frame 7 — dissipating smoke
          [
            "  #{d}.#{x}       #{d}.#{x}       #{d}.#{x}       #{d}.#{x}",
            "      #{d}*#{x}            #{d}*#{x}",
            "         #{d}. #{k}::: #{d}.#{x}",
            "    #{d}*#{x}   #{k}::#{d}.....#{k}::#{x}   #{d}*#{x}",
            "        #{k}:#{d}..   ..#{k}:#{x}",
            "    #{d}*#{x}   #{k}::#{d}.....#{k}::#{x}   #{d}*#{x}",
            "         #{d}' #{k}::: #{d}'#{x}",
            "      #{d}*#{x}            #{d}*#{x}",
            "  #{d}'#{x}       #{d}'#{x}       #{d}'#{x}       #{d}'#{x}",
            "",
          ],
          # Frame 8 — fading embers
          [
            "",
            "     #{d}.#{x}         #{d}.#{x}",
            "",
            "          #{k}. . .#{x}",
            "   #{d}.#{x}    #{k}.     .#{x}    #{d}.#{x}",
            "          #{k}' ' '#{x}",
            "",
            "     #{d}'#{x}         #{d}'#{x}",
            "",
            "",
          ],
      ]

      # Pad lines so all rows in each frame have equal stripped length —
      # prevents the player's per-line centering from misaligning the art.
      raw_frames.each do |frame|
        max = frame.map { |l| l.gsub(/\e\[[0-9;]*m/, "").length }.max
        frame.map! { |l| l + " " * (max - l.gsub(/\e\[[0-9;]*m/, "").length) }
      end

      DATA = {
        name: "Explosion",
        fps: 8,
        frames: raw_frames
      }.freeze
    end
  end
end
