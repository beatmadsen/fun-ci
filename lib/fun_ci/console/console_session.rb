# frozen_string_literal: true

require "json"
require_relative "console_state"
require_relative "../tui/key_handler"

module FunCi
  module Console
    # The console's half of the renderer conversation (renderer-protocol.md):
    # it reads the renderer's lines and writes protocol messages to the port.
    # Ruby decides what is true here; drawing it is the renderer's job.
    class ConsoleSession
      VERSION = 1

      def self.build(board_data:, port:, clock:)
        key_handler = Tui::KeyHandler.new(board_data: board_data)
        new(state: ConsoleState.new(board_data: board_data, key_handler: key_handler, clock: clock), port: port)
      end

      def initialize(state:, port:)
        @state = state
        @port = port
        @finished = false
      end

      def start = @port.write(t: "hello", v: VERSION)

      def receive(line)
        message = JSON.parse(line)
        case message["t"]
        when "ready" then refresh
        when "key" then key(message["key"])
        end
      end

      # Sends what the runs look like now, as each poll does.
      def refresh = @state.updates.each { |message| @port.write(message) }

      def finished? = @finished

      private

      def key(key)
        return refresh unless @state.press(key) == :quit

        @finished = true
        @port.write(t: "quit")
      end
    end
  end
end
