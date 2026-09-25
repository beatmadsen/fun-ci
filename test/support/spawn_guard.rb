# frozen_string_literal: true

# Unit and acceptance tests never start a process, directly or through the
# code they call; tests that must, live in test/integration. A spawn, fork
# or exec during a fast-lane test raises and fails it, naming the test.
# FUN_CI_FAST_LANES (PATH-separated directories) replaces the default lanes.
module SpawnGuard
  class Forbidden < SecurityError; end

  ROOT = File.expand_path("../..", __dir__)
  DEFAULT_LANES = %w[test/unit test/acceptance].map { |lane| File.join(ROOT, lane) }.join(File::PATH_SEPARATOR)

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
      @lanes = ENV.fetch("FUN_CI_FAST_LANES", DEFAULT_LANES).split(File::PATH_SEPARATOR).map { |lane| "#{lane}/" }
      [Kernel, Kernel.singleton_class, Process.singleton_class].each { |target| target.prepend(Hooks) }
      IO.singleton_class.prepend(Popen)
      Minitest::Test.prepend(TrackTest)
    end

    def enter(test, file)
      @test = test
      @fast = @lanes.any? { |lane| File.expand_path(file).start_with?(lane) }
    end

    def label(receiver, name, bare) = receiver == Process ? "Process.#{name}" : bare

    def check(call)
      raise Forbidden, "#{@test} started a process (#{call}); tests that must live in test/integration" if @fast
    end
  end
end
