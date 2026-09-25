# frozen_string_literal: true

require "json"
require_relative "console_state"
require_relative "view"
require_relative "key_handler"

module FunCi
  module Console
    # The console's half of the renderer conversation (renderer-protocol.md):
    # it reads the renderer's lines and writes protocol messages to the port.
    # Ruby decides what is true here; drawing it is the renderer's job.
    class ConsoleSession
      VERSION = 1

      # `log` takes what the renderer got wrong (ConsoleLog).
      def self.build(board_data:, port:, clock:, log:)
        view = View.new(key_handler: KeyHandler.new(board_data: board_data))
        new(state: ConsoleState.new(board_data: board_data, view: view, clock: clock), port: port, log: log)
      end

      def initialize(state:, port:, log:)
        @state = state
        @port = port
        @log = log
        @finished = false
      end

      def start = @port.write(t: "hello", v: VERSION)

      # A line the renderer wrote. One it got wrong is logged, never raised.
      def receive(line)
        message = JSON.parse(line)
        message.is_a?(Hash) ? handle(message) : @log.write("the renderer sent a line that is not a message: #{line}")
      rescue JSON::ParserError
        @log.write("the renderer sent a line that is not JSON: #{line.inspect}")
      end

      # Sends what the runs look like now, as each poll does.
      def refresh = @state.updates.each { |message| @port.write(message) }

      def finished? = @finished

      private

      def handle(message)
        case message["t"]
        when "ready", "resize" then resize(message["rows"])
        when "key" then key(message["key"])
        when "error" then @log.write("the renderer reported a #{message["code"]} error: #{message["detail"]}")
        else @log.write("the renderer sent a message of unknown type #{message["t"].inspect}")
        end
      end

      def resize(rows)
        @state.resize(rows)
        refresh
      end

      def key(key)
        return refresh unless @state.press(key) == :quit

        @finished = true
        @port.write(t: "quit")
      end
    end
  end
end
