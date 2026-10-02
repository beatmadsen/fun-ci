# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require_relative "confinement_hooks"
require_relative "stray_processes"

# Tests touch only a temp root private to this run. Its name is short because
# the parallel executor puts a Unix socket in it, and socket paths are capped
# at 104 bytes. TMPDIR points at it, and XDG_STATE_HOME at a directory in it,
# so code that writes under Dir.tmpdir, and fun-ci's own database, land in
# the sandbox too, in this process and every child. A file write, a SQLite database or a git
# command outside it raises and fails the test that did it, naming the path.
module ConfinementGuard
  class Escape < SecurityError; end

  @escapes = []

  class << self
    attr_reader :root, :escapes

    def install
      remove_roots_of_finished_runs unless ENV["MUTATION_TESTING"]
      @short = File.join(Dir.tmpdir, "fci-#{Process.pid}")
      Dir.mkdir(@short, 0o700)
      @root = File.realpath(@short)
      ENV["TMPDIR"] = @short
      ENV["XDG_STATE_HOME"] = File.join(@short, "state")
      ConfinementHooks.install
    end

    # The root as TMPDIR names it, and as its real path: a command line may hold either.
    def roots = [@short, @root].uniq

    # A root outlives its run: the parallel executor's socket in it is only
    # removed as the process exits, and a run that never reached its end
    # (the mutation lane, one cut short) may have left processes running in
    # it. The next run stops those and clears it; in the mutation lane, whose
    # every test file and mutant is a process that installs this, the lane's
    # boot does it once instead (test/mutation_boot.rb), since a ps forked from
    # each of them doubled its time.
    def remove_roots_of_finished_runs
      Dir.glob(File.join(Dir.tmpdir, "fci-*")).reject { |root| alive?(root[/fci-(\d+)\z/, 1].to_i) }
         .each { |root| remove_root(root) }
    end

    # Another run may be removing the same root, so its real path is taken
    # from its parent, which stays.
    def remove_root(root)
      StrayProcesses.stop([root, File.join(File.realpath(File.dirname(root)), File.basename(root))].uniq)
      FileUtils.rm_rf(root)
    end
    private :remove_root

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

    def alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
    end

    # The deepest existing ancestor decides, so /var and /private/var agree.
    # A path that exists is its own real path, with no slash added.
    def real_path(path)
      existing = path
      existing = File.dirname(existing) until File.exist?(existing)
      rest = path.delete_prefix(existing)
      rest.empty? ? File.realpath(existing) : File.join(File.realpath(existing), rest)
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
