# frozen_string_literal: true

require_relative "animation"
require_relative "animation_compositor"
require_relative "animation_library"
require_relative "header_animation_manager"
require_relative "stage_change_detector"

module FunCi
  class AnimationRenderer
    HEADER_HEIGHT = HeaderAnimationManager::HEADER_HEIGHT

    def initialize(animation_library: AnimationLibrary)
      @previous_runs = []
      @animations = []
      @header_manager = HeaderAnimationManager.new(animation_library: animation_library)
    end

    def render(screen, runs)
      detect_and_queue(runs)

      screen.save_cursor
      render_header_overlay(screen)
      render_stage_overlays(screen, runs)
      render_footer_overlay(screen, runs)
      screen.restore_cursor

      advance_all
      expire_finished
    end

    def any_active?
      @animations.any? { |a| !a.finished? } || @header_manager.any_active_event?
    end

    def active_count
      @animations.count { |a| !a.finished? }
    end

    private

    def detect_and_queue(runs)
      changes = StageChangeDetector.detect(@previous_runs, runs)
      @previous_runs = snapshot(runs)
      changes.each { |change| queue_animation(change, runs) }
    end

    def queue_animation(change, runs)
      run_status = runs.find { |r| r[:id] == change.run_id }&.dig(:status)

      case change.to
      when "failed"
        add_animation(:failure, change.run_id, change.stage)
        @header_manager.trigger_failure
      when "timed_out"
        add_animation(:timeout, change.run_id, change.stage)
      when "completed"
        if run_status == "completed"
          add_animation(:success, change.run_id, change.stage)
          @header_manager.trigger_success
        else
          add_animation(:stage_pass, change.run_id, change.stage)
        end
      end
    end

    def add_animation(type, run_id, stage)
      @animations.reject! do |a|
        a.type == type && a.run_id == run_id && a.stage == stage
      end
      @animations << Animation.new(type: type, run_id: run_id, stage: stage)
    end

    def render_header_overlay(screen)
      @header_manager.current_lines(screen.width).each_with_index do |line, i|
        screen.write_at(1 + i, 1, line)
      end

      anim = highest_priority(:has_header?)
      return unless anim

      overlay = AnimationCompositor.header_overlay(anim, screen.width)
      screen.write_at(1, 1, "#{overlay}\e[K") if overlay
    end

    def render_footer_overlay(screen, runs)
      anim = highest_priority(:has_footer?)
      return unless anim

      footer_row = HEADER_HEIGHT + (runs.length * 2) + 1
      overlay = AnimationCompositor.footer_overlay(anim, screen.width)
      screen.write_at(footer_row, 1, "#{overlay}\e[K") if overlay
    end

    def render_stage_overlays(screen, runs)
      @animations.each do |anim|
        next if anim.finished?

        run_index = runs.index { |r| r[:id] == anim.run_id }
        next unless run_index

        row = HEADER_HEIGHT + 1 + (run_index * 2)
        run = runs[run_index]
        text = AnimationCompositor.stage_text_for(run, anim.stage)
        next unless text

        overlay = AnimationCompositor.stage_column_overlay(anim, text, 0)
        next unless overlay

        col = AnimationCompositor.stage_col_for(run, anim.stage)
        screen.write_at(row, col, overlay) if col
      end
    end

    def highest_priority(predicate)
      @animations
        .select { |a| a.send(predicate) && !a.finished? }
        .max_by(&:priority)
    end

    def advance_all
      @animations.each { |a| a.advance! unless a.finished? }
      @header_manager.advance!
    end

    def expire_finished
      @animations.reject!(&:finished?)
      @header_manager.expire_if_finished!
    end

    def snapshot(runs)
      runs.map do |r|
        {
          id: r[:id],
          stages: (r[:stages] || []).map do |s|
            { stage: s[:stage], status: s[:status] }
          end
        }
      end
    end
  end
end
