# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/call_scanner"

class TestCallScanner < Minitest::Test
  {
    "spawn" => %(spawn("ls")),
    "fork" => "fork { exit }",
    "system" => %(system("git", "init")),
    "exec" => %(exec("ls")),
    "backticks" => "`ls`",
    "interpolated backticks" => "`ls \#{dir}`",
    "%x" => "%x(ls)",
    "Open3" => %(Open3.capture2e("ls")),
    "IO.popen" => %(IO.popen("ls", &:read)),
    "Process.spawn" => %(Process.spawn("ls")),
    "Process.fork" => "Process.fork { exit }",
    "Process.kill" => %(Process.kill("TERM", pid)),
    "Kernel.system" => %(Kernel.system("ls"))
  }.each do |form, source|
    define_method(:"test_should_report_#{form.tr(" .%", "___")}_as_spawning_with_file_and_line") do
      assert_equal ["probe.rb:2"], located(offences("x = 1\n#{source}\n", CallScanner::SPAWNING))
    end
  end

  {
    "sleep" => "sleep 0.1",
    "Kernel.sleep" => "Kernel.sleep(1)",
    "Thread.pass" => "Thread.pass",
    "Timeout.timeout" => "Timeout.timeout(1) { work }",
    "instance_variable_get" => "board.instance_variable_get(:@rows)",
    "instance_variable_set" => "board.instance_variable_set(:@rows, [])"
  }.each do |form, source|
    define_method(:"test_should_report_#{form.tr(".", "_")}_as_nondeterministic") do
      assert_equal ["probe.rb:1"], located(offences(source, CallScanner::NONDETERMINISTIC))
    end
  end

  def test_should_name_the_call_it_found
    assert_equal ["probe.rb:1 calls Open3.capture2e"], offences(%(Open3.capture2e("ls")), CallScanner::SPAWNING)
  end

  def test_should_not_report_a_method_on_another_receiver_that_shares_a_name
    assert_empty offences(%(runner.spawn("ls"); client.system_name; clock.sleep(1)), CallScanner::SPAWNING)
  end

  def test_should_not_report_a_string_that_mentions_a_call
    assert_empty offences(%("run system tests"; "sleep 300"), CallScanner::NONDETERMINISTIC)
  end

  private

  def offences(source, rules) = CallScanner.new(source, "probe.rb", rules).offences
  def located(found) = found.map { |offence| offence[/\A\S+:\d+/] }
end
