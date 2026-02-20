# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/installer"
require "tmpdir"
require "stringio"

class TestInitCliRubyProject < Minitest::Test
  def test_should_create_executable_scripts_for_ruby_project
    # Given a project directory with a Gemfile
    Dir.mktmpdir("fun-ci-init-test") do |dir|
      File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
      stdout = StringIO.new

      # When we run init
      exit_code = FunCi::Installer.run(project_root: dir, stdout: stdout)

      # Then it should succeed and create all four executable scripts
      assert_equal 0, exit_code, "Should return success exit code"
      %w[lint.sh build.sh fast.sh slow.sh].each do |script|
        path = File.join(dir, ".fun-ci", script)
        assert File.exist?(path), "#{script} should exist"
        assert File.executable?(path), "#{script} should be executable"
      end

      # And the scripts should be Ruby/Bundler templates
      content = File.read(File.join(dir, ".fun-ci", "fast.sh"))
      assert_match(/bundle exec/, content, "Ruby template should use bundler")
    end
  end
end
