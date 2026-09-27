# frozen_string_literal: true

require "fileutils"

# Writes an executable shell script for a process test without writing a new
# executable: `path` becomes a hard link to a tracked script that sources
# `<path>.body`. macOS scans each freshly written executable on its first
# exec, long enough to stall a test held to a deadline. Where the link can't
# cross file systems (Linux, where nothing scans) it is a copy.
module BodyScript
  RUN = File.expand_path("../fixtures/body_script/run", __dir__)

  def self.write(path, body)
    FileUtils.mkdir_p(File.dirname(path))
    File.write("#{path}.body", "#{body}\n")
    link(path)
    path
  end

  def self.link(path)
    File.link(RUN, path)
  rescue Errno::EXDEV
    FileUtils.cp(RUN, path, preserve: true)
  end
end
