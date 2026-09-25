# frozen_string_literal: true

require "fileutils"

# Writes a project's .fun-ci/ scripts. Each script records the arguments it
# was called with in .fun-ci-args/<script>, then runs the body it was given.
class ScriptedProject
  SCRIPTS = %w[lint.sh build.sh fast.sh slow.sh].freeze

  def initialize(dir)
    @dir = dir
  end

  def write(bodies = {}, mode: 0o755)
    FileUtils.mkdir_p([scripts_dir, args_dir])
    Dir.children(args_dir).each { |name| File.delete(File.join(args_dir, name)) }
    SCRIPTS.each { |script| write_script(script, bodies.fetch(script, "exit 0"), mode) }
  end

  def arguments_for(script)
    path = File.join(args_dir, script)
    File.size?(path) ? File.read(path).split : nil
  end

  def remove(script) = File.delete(File.join(scripts_dir, script))
  def chmod(script, mode) = File.chmod(mode, File.join(scripts_dir, script))

  private

  def scripts_dir = File.join(@dir, ".fun-ci")
  def args_dir = File.join(@dir, ".fun-ci-args")

  def write_script(script, body, mode)
    path = File.join(scripts_dir, script)
    File.write(path, "#!/bin/sh\necho \"$@\" > #{File.join(args_dir, script)}\n#{body}\n")
    File.chmod(mode, path)
  end
end
