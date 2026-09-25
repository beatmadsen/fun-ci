# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/spawn_scanner"

class TestSpawnScanner < Minitest::Test
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
    "Kernel.system" => %(Kernel.system("ls"))
  }.each do |form, source|
    define_method(:"test_should_report_#{form.tr(" .%", "___")}_with_file_and_line") do
      assert_equal ["probe.rb:2"], located(SpawnScanner.new("x = 1\n#{source}\n", "probe.rb").offences)
    end
  end

  def located(offences) = offences.map { |offence| offence[/\A\S+:\d+/] }

  def test_should_name_the_call_it_found
    assert_equal ["probe.rb:1 calls Open3.capture2e"], SpawnScanner.new(%(Open3.capture2e("ls")), "probe.rb").offences
  end

  def test_should_not_report_a_method_on_another_receiver_that_shares_a_name
    assert_empty SpawnScanner.new(%(runner.spawn("ls"); client.system_name), "probe.rb").offences
  end

  def test_should_not_report_a_string_that_mentions_a_spawn
    assert_empty SpawnScanner.new(%("run system tests"), "probe.rb").offences
  end
end
