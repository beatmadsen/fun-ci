# frozen_string_literal: true

# Only tests under test/integration/process start processes, directly or
# through the code they call. A spawn, fork or exec during any other test
# raises and fails it, naming the test, which keeps every other test fast
# enough for the mutation lane. FUN_CI_NO_SPAWN_DIRS and FUN_CI_SPAWN_DIRS
# (PATH-separated) replace the defaults.
module SpawnGuard
  class Forbidden < SecurityError; end

  ROOT = File.expand_path("../..", __dir__)
  NO_SPAWN = File.join(ROOT, "test")
  SPAWN = File.join(ROOT, "test/integration/process")

  module Hooks
    { spawn: "spawn", system: "system", fork: "fork", exec: "exec", "`": "backticks" }.each do |name, label|
      define_method(name) do |*args, **opts, &block|
        SpawnGuard.check(SpawnGuard.label(self, name, label))
        super(*args, **opts, &block)
      end
    end
  end

  module Popen
    def popen(...)
      SpawnGuard.check("IO.popen")
      super
    end
  end

  module TrackTest
    def before_setup
      SpawnGuard.enter("#{self.class}##{name}", method(name).source_location.first)
      super
    end

    def after_teardown
      super
    ensure
      SpawnGuard.enter("", "")
    end
  end

  class << self
    def install
      @forbidden = dirs("FUN_CI_NO_SPAWN_DIRS", NO_SPAWN)
      @allowed = dirs("FUN_CI_SPAWN_DIRS", SPAWN)
      [Kernel, Kernel.singleton_class, Process.singleton_class].each { |target| target.prepend(Hooks) }
      IO.singleton_class.prepend(Popen)
      Minitest::Test.prepend(TrackTest)
    end

    def enter(test, file)
      @test = test
      @fast = within?(file, @forbidden) && !within?(file, @allowed)
    end

    def dirs(variable, default) = ENV.fetch(variable, default).split(File::PATH_SEPARATOR).map { |dir| "#{dir}/" }
    def within?(file, dirs) = dirs.any? { |dir| File.expand_path(file).start_with?(dir) }

    def label(receiver, name, bare) = receiver == Process ? "Process.#{name}" : bare

    def check(call)
      raise Forbidden, "#{@test} started a process (#{call}); tests that must live in test/integration/process" if @fast
    end
  end
end
