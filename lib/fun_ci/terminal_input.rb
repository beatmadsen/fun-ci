# frozen_string_literal: true

module FunCi
  class TerminalInput
    def initialize(input:, width_provider: nil)
      @input = input
      @width_provider = width_provider
      @signal_read = nil
      @signal_write = nil
    end

    def setup_signal_trap
      return unless @width_provider

      @signal_read, @signal_write = IO.pipe
      Signal.trap("WINCH") do
        @signal_write&.write_nonblock(".") rescue nil # rubocop:disable Style/RescueModifier
      end
    end

    def check_width
      return nil unless @width_provider

      @width_provider.call
    end

    def setup_raw_mode
      @input.raw! if @input.respond_to?(:raw!)
    rescue Errno::ENOTTY
      # Not a terminal (testing)
    end

    def restore_terminal
      @input.cooked! if @input.respond_to?(:cooked!)
    rescue Errno::ENOTTY
      # Not a terminal
    end

    def read_key_with_timeout(timeout)
      return nil unless @input.respond_to?(:read_nonblock)

      watched = [@input]
      watched << @signal_read if @signal_read
      ready = IO.select(watched, nil, nil, timeout)
      return nil unless ready

      if @signal_read && ready[0].include?(@signal_read)
        @signal_read.read_nonblock(1) rescue nil # rubocop:disable Style/RescueModifier
        return nil unless ready[0].include?(@input)
      end

      byte = @input.read_nonblock(1)
      if byte == "\e"
        seq = @input.read_nonblock(2) rescue "" # rubocop:disable Style/RescueModifier
        case seq
        when "[A" then :up
        when "[B" then :down
        else :escape
        end
      else
        byte
      end
    rescue IO::WaitReadable, EOFError
      nil
    end
  end
end
