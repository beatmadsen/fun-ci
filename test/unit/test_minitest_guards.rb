# frozen_string_literal: true

require_relative "../test_helper"

# What test_helper's MinitestGuards refuse, each before it can take the machine
# down: a test calling Minitest's own `run` from inside itself starts itself
# over without end, opening a database each time, in every worker at once.
class TestMinitestGuards < Minitest::Test
  def test_should_fail_a_test_that_calls_minitest_s_run_from_inside_itself
    result = scratch_test_class { define_method(:test_calls_run) { run } }.new(:test_calls_run).run

    assert_includes result.failures.first.message, "called Minitest's run from inside itself"
  end

  def test_should_refuse_an_instance_method_named_after_one_of_minitest_s
    error = assert_raises(MinitestGuards::Clash) { class_defining(:run) }

    assert_includes error.message, "run"
  end

  def test_should_refuse_a_class_method_named_after_one_of_minitest_s
    assert_raises(MinitestGuards::Clash) { class_defining_class_method(:runnable_methods) }
  end

  def test_should_refuse_a_module_a_test_includes_that_brings_a_method_named_after_one_of_minitest_s
    kit = Module.new { define_method(:name) { "kit" } }

    assert_raises(MinitestGuards::Clash) { scratch_test_class { include kit } }
  end

  def test_should_let_a_test_define_its_setup
    assert class_defining(:setup)
  end

  def test_should_let_a_test_define_a_helper_of_its_own
    assert class_defining(:job_run)
  end

  private

  def class_defining(name) = scratch_test_class { define_method(name) { nil } }
  def class_defining_class_method(name) = scratch_test_class { define_singleton_method(name) { [] } }

  # A test class that the suite itself never runs.
  def scratch_test_class(&)
    Class.new(Minitest::Test, &)
  ensure
    Minitest::Runnable.runnables.delete_if { |runnable| runnable.name.nil? }
  end
end
