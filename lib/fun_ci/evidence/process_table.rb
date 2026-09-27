# frozen_string_literal: true

require "open3"

module FunCi
  module Evidence
    # The processes running on the machine, as `ps` lists them: BSD and
    # procps take `-A -o pid=,ppid=,pgid=,etime=,args=`; busybox (the musl
    # target's) takes neither -A nor `=`, and lists every process with a
    # header under `-o pid,ppid,pgid,etime,args`.
    module ProcessTable
      Row = Data.define(:pid, :ppid, :pgid, :seconds, :command)
      COMMANDS = [%w[ps -A -o pid=,ppid=,pgid=,etime=,args=], %w[ps -o pid,ppid,pgid,etime,args]].freeze
      LINE = /\A\s*(\d+)\s+(\d+)\s+(\d+)\s+(?:(\d+)-)?(?:(\d+):)?(\d+):(\d+)\s+(.*)\z/

      # What `ps` lists now, from the first form this machine's ps takes.
      def self.now
        COMMANDS.each do |command|
          listing, status = Open3.capture2e(*command)
          return parse(listing) if status.success?
        end
        []
      end

      def self.parse(listing) = listing.lines(chomp: true).filter_map { |line| row(line) }

      def self.row(line)
        match = LINE.match(line)
        return nil unless match

        Row.new(pid: match[1].to_i, ppid: match[2].to_i, pgid: match[3].to_i, command: match[8],
                seconds: seconds(match.captures[3, 4].map(&:to_i)))
      end

      # Elapsed [days, hours, minutes, seconds] in seconds.
      def self.seconds(parts) = parts.zip([86_400, 3600, 60, 1]).sum { |count, unit| count * unit }
      private_class_method :row, :seconds
    end
  end
end
