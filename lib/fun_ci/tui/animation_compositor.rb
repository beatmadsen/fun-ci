# frozen_string_literal: true

require_relative "ansi"
require_relative "animation_frames"
require_relative "row_formatter"
require_relative "duration_formatter"

module FunCi
  module Tui
    module AnimationCompositor
      RESET = Ansi::RESET
      STAGE_STAGGER = { "lint" => 0, "build" => 2, "fast" => 4, "slow" => 6 }.freeze

      def self.header_overlay(animation, width)
        frames = case animation.type
                 when :failure then AnimationFrames.failure_header(width)
                 when :success then AnimationFrames.success_header(width)
                 when :timeout then AnimationFrames.timeout_header(width)
                 else return nil
                 end
        frame_at(frames, animation.frame)
      end

      def self.footer_overlay(animation, width)
        frames = case animation.type
                 when :failure
                   AnimationFrames.failure_footer(animation.stage || "stage", width)
                 when :success then AnimationFrames.success_footer(width)
                 else return nil
                 end
        frame_at(frames, animation.frame)
      end

      def self.stage_column_overlay(animation, stage_text, col)
        case animation.type
        when :stage_pass  then color_flash(animation, stage_text, AnimationFrames.stage_pass_colors)
        when :timeout     then color_flash(animation, stage_text, AnimationFrames.timeout_colors)
        when :failure     then failure_flanks(animation, stage_text)
        when :success     then sparkle_sweep(animation, stage_text)
        end
      end

      def self.stage_text_for(run, stage_name)
        stage = run[:stages]&.find { |s| s[:stage] == stage_name }
        return nil unless stage

        name = RowFormatter::STAGE_NAMES[stage[:stage]] || stage[:stage]
        dur = stage[:duration] ? DurationFormatter.format(stage[:duration]) : "--"
        case stage[:status]
        when "completed" then "#{name} #{dur}"
        when "failed"    then "#{name} FAIL #{dur}"
        when "timed_out" then "#{name} TIMEOUT #{dur}"
        else "#{name} --"
        end
      end

      def self.stage_col_for(run, stage_name)
        project = run[:project_path] ? "  #{File.basename(run[:project_path])}" : ""
        prefix_len = 2 + 7 + 2 + run[:branch].to_s.length + project.length + 2
        (run[:stages] || []).each do |s|
          return prefix_len + 1 if s[:stage] == stage_name
          prefix_len += stage_text_for(run, s[:stage]).to_s.length + 2
        end
        nil
      end

      def self.color_flash(animation, stage_text, colors)
        idx = [animation.frame, colors.length - 1].min
        "#{colors[idx]}#{Ansi.strip(stage_text)}#{RESET}"
      end
      private_class_method :color_flash

      def self.failure_flanks(animation, stage_text)
        particles = AnimationFrames.failure_particles
        return nil if animation.frame >= particles.length

        p = particles[animation.frame]
        plain = Ansi.strip(stage_text)
        return plain if p[:chars].empty?

        left = p[:chars].reverse
        right = p[:chars]
        "#{p[:color]}#{left}#{RESET} #{Ansi.bold_red(plain)} #{p[:color]}#{right}#{RESET}"
      end
      private_class_method :failure_flanks

      def self.sparkle_sweep(animation, stage_text)
        plain = Ansi.strip(stage_text)
        stagger = STAGE_STAGGER[animation.stage] || 0
        pos = animation.frame - stagger
        return nil if pos < 0 || pos > plain.length

        result = plain.chars.map { |c| "\e[32m#{c}" }
        result[pos] = "\e[1;33m#{plain[pos]}" if pos < plain.length
        "#{result.join}#{RESET}"
      end
      private_class_method :sparkle_sweep

      def self.frame_at(frames, index)
        return nil if index >= frames.length

        frames[index]
      end
      private_class_method :frame_at
    end
  end
end
