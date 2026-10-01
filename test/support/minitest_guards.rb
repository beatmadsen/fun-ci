# frozen_string_literal: true

# Two mistakes with Minitest's own method names, refused before they can do
# harm. A test that calls Minitest's `run` from inside itself (a helper of
# that name renamed, a call left behind) starts itself over without end, and
# with a database opened in each setup, every worker of the parallel executor
# eats memory until the machine falls over. A helper named after one of
# Minitest's methods replaces it, and the executor fails the whole file with
# "result not reported". The first fails its test at once; the second fails
# the file as it loads, in any lane, a single file run on its own included.
module MinitestGuards
  class Clash < StandardError; end

  HOOKS = %i[setup teardown before_setup after_setup before_teardown after_teardown].freeze

  # Fails a test that re-enters its own run.
  module Reentry
    def run
      raise "#{self.class}##{name} called Minitest's run from inside itself; name the helper something else" if @in_run

      begin
        @in_run = true
        super
      ensure
        @in_run = false
      end
    end
  end

  # Refuses a test class's method named after one of Minitest's, its own or
  # one a module it includes brings.
  module Names
    def include(*modules)
      modules.flat_map { |mod| mod.instance_methods(false) }.each { |name| method_added(name) }
      super
    end

    def method_added(name)
      super
      MinitestGuards.refuse(self, name, MinitestGuards.instance_names)
    end

    def singleton_method_added(name)
      super
      MinitestGuards.refuse(self, name, MinitestGuards.class_names)
    end
  end

  def self.install
    Minitest::Test.prepend(Reentry)
    Minitest::Test.singleton_class.prepend(Names)
  end

  def self.refuse(klass, name, taken)
    return unless klass < Minitest::Test && taken.include?(name)

    raise Clash, "#{klass.name || "a test class"} defines #{name}, which is Minitest's own: name it something else"
  end

  def self.instance_names
    @instance_names ||= minitest_own(Minitest::Test.instance_methods + Minitest::Test.private_instance_methods,
                                     Object.instance_methods + Object.private_instance_methods) - HOOKS
  end

  def self.class_names
    @class_names ||= minitest_own(Minitest::Test.singleton_methods(true) + Minitest::Test.private_methods,
                                  Class.instance_methods + Class.private_instance_methods)
  end

  def self.minitest_own(methods, plain)
    (methods - plain).reject { |method| method.start_with?("assert", "refute", "test_", "_") }
  end
end
