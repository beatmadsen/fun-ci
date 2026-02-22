# frozen_string_literal: true

module FunCi
  class Animation
    TYPES = {
      failure: { total_frames: 40, priority: 3 },
      timeout: { total_frames: 4, priority: 2 },
      success: { total_frames: 40, priority: 1 },
      stage_pass: { total_frames: 3, priority: 0 }
    }.freeze

    attr_reader :type, :run_id, :stage, :frame

    def initialize(type:, run_id:, stage: nil)
      raise ArgumentError, "Unknown animation type: #{type}" unless TYPES.key?(type)

      @type = type
      @run_id = run_id
      @stage = stage
      @frame = 0
    end

    def advance!
      @frame += 1
    end

    def finished?
      frame >= total_frames
    end

    def total_frames
      TYPES[@type][:total_frames]
    end

    def priority
      TYPES[@type][:priority]
    end

    def has_header?
      %i[failure timeout success].include?(@type)
    end

    def has_footer?
      %i[failure success].include?(@type)
    end
  end
end
