# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "confinement_hooks"

# Tests touch only a temp root private to this run. Its name is short because
# the parallel executor puts a Unix socket in it, and socket paths are capped
# at 104 bytes. TMPDIR points at it, so
# code that writes under Dir.tmpdir (fun-ci's own database lives there)
# writes into the sandbox too. A file write, a SQLite database or a git
# command outside it raises and fails the test that did it, naming the path.
module ConfinementGuard
  class Escape < SecurityError; end

  @escapes = []

  class << self
    attr_reader :root, :escapes

    def install
      remove_roots_of_finished_runs
      short = File.join(Dir.tmpdir, "fci-#{Process.pid}")
      Dir.mkdir(short, 0o700)
      @root = File.realpath(short)
      ENV["TMPDIR"] = short
      ConfinementHooks.install
    end

    def installed? = !@root.nil? && ConfinementHooks.installed?

    def check(path, action)
      return if inside?(path)

      escapes << "#{action} outside the test temp root: #{path}"
      raise Escape, escapes.last
    end

    def inside?(path)
      real = real_path(File.expand_path(path.to_s))
      real == File::NULL || real == @root || real.start_with?("#{@root}/")
    end

    private

    # A root outlives its run: the parallel executor's socket in it is only
    # removed as the process exits. The next run clears it.
    def remove_roots_of_finished_runs
      Dir.glob(File.join(Dir.tmpdir, "fci-*")).each do |root|
        FileUtils.rm_rf(root) unless alive?(root[/fci-(\d+)\z/, 1].to_i)
      end
    end

    def alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
    end

    # The deepest existing ancestor decides, so /var and /private/var agree.
    def real_path(path)
      existing = path
      existing = File.dirname(existing) until File.exist?(existing)
      File.join(File.realpath(existing), path.delete_prefix(existing))
    end
  end

  module CheckAfterTest
    def after_teardown
      super
      escaped = ConfinementGuard.escapes.dup.tap { ConfinementGuard.escapes.clear }
      flunk "#{self.class}##{name} #{escaped.join("; ")}" if escaped.any?
    end
  end
end
