# frozen_string_literal: true

module FunCi
  module Animations
    module Running
      # Rocket cruising through a starfield — exhaust cycles short/medium/long
      # Body pipes fixed at cols 20 & 25, nose/tail at 21-24/22-23

      w  = "\e[1;37m"     # bold white (hull)
      c  = "\e[1;36m"     # bold cyan (window, bright stars)
      dc = "\e[36m"       # cyan (mid stars)
      dm = "\e[2;36m"     # dim cyan (far stars)
      y  = "\e[1;33m"     # bold yellow (flame core)
      o  = "\e[38;5;208m" # orange (flame edge)
      r  = "\e[2;33m"     # dim yellow (flame trail)
      x  = "\e[0m"        # reset

      raw_frames = [
        [ # frame 1 — short exhaust
          "            #{dm}.#{x}                    #{c}*#{x}            #{dm}.#{x}",
          "   #{c}.#{x}                        #{dm}.#{x}",
          "                       #{dc}.#{x}                       #{dm}.#{x}",
          "#{dm}.#{x}                                    #{dc}.#{x}",
          "                      #{w}/\\#{x}",
          "                     #{w}/  \\#{x}",
          "             #{o}~#{x}      #{w}| #{c}oo#{w} |#{x}              #{c}*#{x}",
          "           #{y}=#{o}=#{r}=~#{x}     #{w}|    |====>#{x}",
          "             #{o}~#{x}      #{w}|#{c}FUN!#{w}|#{x}",
          "                     #{w}\\  /#{x}",
          "                      #{w}\\/#{x}             #{dm}.#{x}",
          " #{dc}.#{x}                                         #{c}.#{x}",
          "            #{dm}.#{x}           #{dc}.#{x}",
          "                                    #{dm}.#{x}",
        ],
        [ # frame 2 — medium exhaust
          "        #{dm}.#{x}                #{c}*#{x}                #{dm}.#{x}",
          "                      #{dm}.#{x}                    #{c}.#{x}",
          "                 #{dc}.#{x}                           #{dm}.#{x}",
          "                                        #{dc}.#{x}",
          "                      #{w}/\\#{x}",
          "                     #{w}/  \\#{x}",
          "           #{o}~~~#{x}      #{w}| #{c}oo#{w} |#{x}            #{c}*#{x}",
          "         #{y}=#{o}==#{r}==~#{x}     #{w}|    |====>#{x}",
          "           #{o}~~~#{x}      #{w}|#{c}FUN!#{w}|#{x}",
          "                     #{w}\\  /#{x}",
          "                      #{w}\\/#{x}         #{dm}.#{x}",
          "                                             #{c}.#{x}",
          "        #{dm}.#{x}               #{dc}.#{x}",
          "#{dc}.#{x}                                #{dm}.#{x}",
        ],
        [ # frame 3 — long exhaust
          "    #{dm}.#{x}            #{c}*#{x}                    #{dm}.#{x}",
          "                  #{dm}.#{x}                          #{c}.#{x}",
          "             #{dc}.#{x}                           #{dm}.#{x}",
          "              #{dm}.#{x}                      #{dc}.#{x}",
          "                      #{w}/\\#{x}",
          "                     #{w}/  \\#{x}",
          "         #{o}~~~~~#{x}      #{w}| #{c}oo#{w} |#{x}          #{c}*#{x}",
          "       #{y}===#{o}==#{r}==~#{x}     #{w}|    |====>#{x}",
          "         #{o}~~~~~#{x}      #{w}|#{c}FUN!#{w}|#{x}",
          "                     #{w}\\  /#{x}",
          "                      #{w}\\/#{x}     #{dm}.#{x}",
          "                                               #{c}.#{x}",
          "    #{dm}.#{x}                   #{dc}.#{x}",
          "                                      #{dm}.#{x}",
        ],
        [ # frame 4 — short exhaust
          "#{dm}.#{x}        #{c}*#{x}                          #{dm}.#{x}",
          "              #{dm}.#{x}                        #{c}.#{x}",
          "         #{dc}.#{x}                               #{dm}.#{x}",
          "          #{dm}.#{x}                          #{dc}.#{x}",
          "                      #{w}/\\#{x}",
          "                     #{w}/  \\#{x}",
          "             #{o}~#{x}      #{w}| #{c}oo#{w} |#{x}        #{c}*#{x}",
          "           #{y}=#{o}=#{r}=~#{x}     #{w}|    |====>#{x}",
          "             #{o}~#{x}      #{w}|#{c}FUN!#{w}|#{x}",
          "                     #{w}\\  /#{x}",
          "                      #{w}\\/#{x}   #{dm}.#{x}",
          "  #{dm}.#{x}                                           #{c}.#{x}",
          "#{dm}.#{x}                       #{dc}.#{x}",
          "                                          #{dm}.#{x}",
        ],
        [ # frame 5 — medium exhaust
          "                    #{c}*#{x}                #{dm}.#{x}          #{c}.#{x}",
          "          #{dm}.#{x}                              #{dm}.#{x}",
          "     #{dc}.#{x}                                   #{dm}.#{x}",
          "      #{dm}.#{x}                              #{dc}.#{x}",
          "                      #{w}/\\#{x}",
          "                     #{w}/  \\#{x}",
          "           #{o}~~~#{x}      #{w}| #{c}oo#{w} |#{x}      #{c}*#{x}",
          "         #{y}=#{o}==#{r}==~#{x}     #{w}|    |====>#{x}",
          "           #{o}~~~#{x}      #{w}|#{c}FUN!#{w}|#{x}",
          "                     #{w}\\  /#{x}",
          "                      #{w}\\/#{x}                #{dm}.#{x}",
          "                                               #{c}.#{x}",
          "              #{dm}.#{x}         #{dc}.#{x}",
          "                                      #{dm}.#{x}",
        ],
        [ # frame 6 — long exhaust
          "              #{c}*#{x}                    #{dm}.#{x}          #{c}.#{x}",
          "      #{dm}.#{x}                                #{dm}.#{x}",
          " #{dc}.#{x}                                       #{dm}.#{x}",
          "  #{dm}.#{x}                                  #{dc}.#{x}",
          "                      #{w}/\\#{x}",
          "                     #{w}/  \\#{x}",
          "         #{o}~~~~~#{x}      #{w}| #{c}oo#{w} |#{x}    #{c}*#{x}",
          "       #{y}===#{o}==#{r}==~#{x}     #{w}|    |====>#{x}",
          "         #{o}~~~~~#{x}      #{w}|#{c}FUN!#{w}|#{x}",
          "                     #{w}\\  /#{x}",
          "                      #{w}\\/#{x}              #{dm}.#{x}",
          "                                                 #{c}.#{x}",
          "          #{dm}.#{x}             #{dc}.#{x}",
          "                                          #{dm}.#{x}",
        ],
      ]

      max = raw_frames.flatten.map { |l| l.gsub(/\e\[[0-9;]*m/, "").length }.max
      raw_frames.each do |frame|
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
