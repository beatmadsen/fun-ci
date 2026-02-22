# frozen_string_literal: true

require_relative "ansi"

module FunCi
  module AnimationFrames
    RESET = Ansi::RESET
    FOOTER_HOLD = 8

    def self.failure_particles
      # Left/right flanking debris per frame (chars expanding outward)
      [
        { chars: "*",     color: "\e[1;31m" },
        { chars: ".*",    color: "\e[1;31m" },
        { chars: ".+*.",  color: "\e[38;5;208m" },
        { chars: "*.+'",  color: "\e[38;5;208m" },
        { chars: "' .",   color: "\e[38;5;52m" },
        { chars: ".",     color: "\e[38;5;52m" },
        { chars: "",      color: "" }
      ]
    end

    def self.failure_header(width)
      boom = "BOOM"
      [
        nil,
        banner(boom, width, "\e[48;5;124m", particles: "* "),
        banner(boom, width, "\e[48;5;166m", particles: "* * "),
        banner(boom, width, "\e[48;5;52m",  particles: ". * * "),
        banner(boom, width, "\e[48;5;236m", particles: "' . * "),
        banner(boom, width, "\e[48;5;236m", particles: ". "),
        nil
      ]
    end

    def self.failure_footer(stage_name, width)
      up = stage_name.upcase
      down = stage_name.downcase
      hold [
        nil,
        center("\e[1;31m>>> #{up} FAILED <<<#{RESET}", ">>> #{up} FAILED <<<", width),
        center("\e[31m>> #{down} failed <<#{RESET}", ">> #{down} failed <<", width),
        center("\e[2;31m> #{down} failed <#{RESET}", "> #{down} failed <", width),
        nil
      ]
    end

    def self.success_header(width)
      text = "ALL PASSED"
      [
        nil,
        banner(text, width, "\e[48;5;22m",  particles: ""),
        banner(text, width, "\e[48;5;22m",  particles: "*  * "),
        banner(text, width, "\e[48;5;22m",  particles: "* .  . "),
        banner(text, width, "\e[48;5;58m",  particles: ". '  ' "),
        banner(text, width, "\e[48;5;22m",  particles: "' "),
        banner(text, width, "\e[48;5;22m",  particles: ""),
        nil
      ]
    end

    def self.success_footer(width)
      hold [
        nil,
        center("\e[1;32m* * * NICE! * * *#{RESET}", "* * * NICE! * * *", width),
        center("\e[32m. + . * NICE! * . + .#{RESET}", ". + . * NICE! * . + .", width),
        center("\e[2;32m' . + .  nice  . + . '#{RESET}", "' . + .  nice  . + . '", width),
        nil
      ]
    end

    def self.timeout_header(width)
      [
        nil,
        banner("TIMED OUT", width, "\e[48;5;58m", particles: ""),
        banner("timed out", width, "\e[48;5;58m", particles: ""),
        nil
      ]
    end

    def self.stage_pass_colors
      ["\e[1;33m", "\e[1;32m", "\e[32m"]
    end

    def self.timeout_colors
      ["\e[1;33m", "\e[33m", "\e[1;33m", "\e[33m"]
    end

    def self.banner(text, width, bg_code, particles: "")
      padded = if particles.empty?
                 text.center(width)
               else
                 inner = "#{particles} #{text} #{particles.reverse}"
                 inner.center(width)
               end
      "#{bg_code}\e[1;37m#{padded}#{RESET}"
    end
    private_class_method :banner

    def self.hold(frames)
      frames.flat_map { |f| Array.new(FOOTER_HOLD, f) }
    end
    private_class_method :hold

    def self.center(colored_text, plain_text, width)
      pad = [(width - plain_text.length) / 2, 0].max
      "#{" " * pad}#{colored_text}"
    end
    private_class_method :center
  end
end
