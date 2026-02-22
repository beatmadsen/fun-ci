# frozen_string_literal: true

require_relative "header_animation_player"
require_relative "looping_animation_player"

module FunCi
  class HeaderAnimationManager
    HEADER_HEIGHT = 14

    def initialize(animation_library:)
      @idle_player = LoopingAnimationPlayer.new(animation_library.idle)
      @header_player = nil
      @animation_library = animation_library
    end

    def trigger_failure
      @header_player = HeaderAnimationPlayer.new(@animation_library.random_failure)
    end

    def trigger_success
      @header_player = HeaderAnimationPlayer.new(@animation_library.random_success)
    end

    def current_lines(width)
      lines = active_player.current_lines(width)
      pad_to_height(lines, HEADER_HEIGHT)
    end

    def advance!
      @idle_player.advance!
      @header_player&.advance!
    end

    def expire_if_finished!
      @header_player = nil if @header_player&.finished?
    end

    def any_active_event?
      @header_player && !@header_player.finished?
    end

    private

    def active_player
      any_active_event? ? @header_player : @idle_player
    end

    def pad_to_height(lines, height)
      return lines if lines.length >= height

      top_pad = (height - lines.length) / 2
      blank = "\e[K"
      Array.new(top_pad, blank) + lines + Array.new(height - lines.length - top_pad, blank)
    end
  end
end
