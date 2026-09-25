# frozen_string_literal: true

require "stringio"
require_relative "../../lib/fun_ci/tui/animation_renderer"
require_relative "../../lib/fun_ci/tui/board_renderer"
require_relative "../../lib/fun_ci/tui/screen"
require_relative "../../lib/fun_ci/tui/spinner"
require_relative "pinned_animations"
require_relative "scenario_state"

module FunCi
  module Contract
    # Replays a scenario through the 1.x renderer, wired as `fun-ci console`
    # wires it, and returns the bytes written for each tick.
    class FrameRecorder
      def self.build
        output = StringIO.new
        state = ScenarioState.new
        library = PinnedAnimations.new
        new(renderer: renderer(output, state, library), state: state, library: library, output: output)
      end

      def self.renderer(output, state, library)
        Tui::BoardRenderer.new(screen: Tui::Screen.new(output: output), spinner: Tui::Spinner.new,
                               animation_renderer: Tui::AnimationRenderer.new(animation_library: library),
                               height_provider: -> { state.rows })
      end
      private_class_method :renderer

      def initialize(renderer:, state:, library:, output:)
        @renderer = renderer
        @state = state
        @library = library
        @output = output
      end

      def replay(messages)
        @renderer.clear
        messages.filter_map { |message| apply(message) }
      end

      private

      def apply(message)
        @library.pin(message["animation"]) if message["animation"]
        @state.apply(message)
        draw_frame if message["t"] == "tick"
      end

      # Same order as one pass of AdminTui#run's loop.
      def draw_frame
        @renderer.begin_frame
        @renderer.resize(@state.cols)
        @renderer.render(@state.board)
        take_output
      end

      def take_output
        @output.string.b.tap { @output.reopen(+"") }
      end
    end
  end
end
