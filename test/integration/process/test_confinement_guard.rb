# frozen_string_literal: true

require_relative "../../test_helper"
require "open3"
require "tmpdir"

# AT-0.4: a test that writes, opens a database or runs git outside the run's
# temp root fails, naming the path. The probe suite nests its own root inside
# this run's, so a sibling directory is outside the probe's root and inside ours.
class TestConfinementGuard < Minitest::Test
  ROOT = File.expand_path("../../..", __dir__)

  def test_should_fail_a_test_that_writes_a_file_outside_the_temp_root
    escape = /TestProbe#test_probe .*outside the test temp root: #{Regexp.escape(outside_path)}/
    assert_match(escape, probe_output(<<~RUBY))
      File.write(#{outside_path.inspect}, "x")
    RUBY
  end

  def test_should_fail_a_test_that_opens_a_database_outside_the_temp_root
    assert_match(/outside the test temp root: #{Regexp.escape(outside_path)}/, probe_output(<<~RUBY))
      SQLite3::Database.new(#{outside_path.inspect}).close
    RUBY
  end

  def test_should_fail_a_test_that_runs_git_outside_the_temp_root
    assert_match(/git .*outside the test temp root: #{Regexp.escape(ROOT)}/, probe_output(<<~RUBY))
      Open3.capture2e("git", "status", chdir: #{ROOT.inspect})
    RUBY
  end

  def test_should_fail_a_test_that_runs_git_in_backticks_outside_the_temp_root
    assert_match(/git .*outside the test temp root: #{Regexp.escape(ROOT)}/, probe_output(<<~RUBY))
      Dir.chdir(#{ROOT.inspect}) { `git status` }
    RUBY
  end

  def test_should_fail_a_test_that_runs_git_through_io_popen_outside_the_temp_root
    assert_match(/git .*outside the test temp root: #{Regexp.escape(ROOT)}/, probe_output(<<~RUBY))
      IO.popen(["git", "status"], chdir: #{ROOT.inspect}, &:read)
    RUBY
  end

  def test_should_pass_a_test_that_writes_inside_the_temp_root
    assert_match(/1 runs, .* 0 failures, 0 errors/, probe_output(<<~RUBY))
      File.write(File.join(Dir.mktmpdir, "x"), "x")
    RUBY
  end

  def setup
    @outside = Dir.mktmpdir("confinement-outside")
  end

  def teardown = FileUtils.rm_rf(@outside)

  private

  def outside_path = File.join(@outside, "probe.sqlite3")

  def probe_output(body)
    Dir.mktmpdir("confinement-guard") do |dir|
      File.write(File.join(dir, "test_probe.rb"), probe(body))
      Open3.capture2e({ "TMPDIR" => Dir.tmpdir }, "ruby", "-I#{ROOT}/test", "-I#{ROOT}/lib", "test_probe.rb",
                      chdir: dir).first
    end
  end

  def probe(body)
    <<~RUBY
      require "test_helper"
      require "sqlite3"
      require "open3"
      class TestProbe < Minitest::Test
        def test_probe
          #{body}
        end
      end
    RUBY
  end
end
