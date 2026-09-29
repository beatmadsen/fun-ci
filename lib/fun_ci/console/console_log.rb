# frozen_string_literal: true

require "fileutils"
require "time"

module FunCi
  module Console
    # The project's .fun-ci/console.log, where the console notes what the
    # renderer got wrong: the terminal is the renderer's, so stderr would
    # draw over it. A .gitignore beside it, unless the project has one there,
    # keeps the log out of the project's commits.
    class ConsoleLog
      attr_reader :path

      def initialize(project_dir:, clock:)
        @path = File.join(project_dir, ".fun-ci", "console.log")
        @clock = clock
      end

      # Appends `text` as one line, stamped with the clock's time in UTC.
      def write(text)
        FileUtils.mkdir_p(File.dirname(@path))
        ignore_file = File.join(File.dirname(@path), ".gitignore")
        File.write(ignore_file, "console.log\n") unless File.exist?(ignore_file)
        File.open(@path, "a") { |file| file.puts("#{@clock.call.utc.iso8601} #{text}") }
      end
    end
  end
end
