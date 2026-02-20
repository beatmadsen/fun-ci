# frozen_string_literal: true

require_relative "ansi"

module FunCi
  class Screen
    def initialize(output: $stdout, width: 80)
      @output = output
      @width = width
    end

    def width=(new_width)
      return if new_width == @width

      clear
      @width = new_width
    end

    def render_header(streak_text:)
      title = " fun-ci"
      if streak_text
        streak_display = Ansi.green(streak_text)
        plain_streak = streak_text
        padding = @width - title.length - plain_streak.length
        padding = 1 if padding < 1
        line = "#{title}#{" " * padding}#{streak_display}"
      else
        line = title.ljust(@width)
      end
      println Ansi.bg_charcoal(Ansi.white(line))
    end

    def render_footer(empty: false)
      if empty
        println Ansi.dim("  q quit")
      else
        println Ansi.dim("  j/k move   c cancel   q quit")
      end
    end

    def render_empty_state
      println ""
      println ""
      println "          No runs yet."
      println ""
      println "          Trigger one:  fun-ci trigger HEAD"
      println "          Or hook it:   fun-ci install-hook pre-push"
      println ""
    end

    def render_board(rows, cursor_index:)
      rows.each_with_index do |row, i|
        if cursor_index == i
          # Replace leading spaces with cursor marker
          println "> #{row.lstrip}"
        else
          println row
        end
      end
    end

    def println(text = "")
      @output.print "#{text}\e[K\r\n"
    end

    def clear
      @output.print "\e[2J\e[H"
    end

    def move_cursor_home
      @output.print "\e[H"
    end

    def clear_below
      @output.print "\e[J"
    end
  end
end
