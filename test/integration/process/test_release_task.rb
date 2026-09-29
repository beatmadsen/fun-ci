# frozen_string_literal: true

require_relative "../../test_helper"
require "open3"

# `rake release` pushes the platform gems before it tags the commit and
# pushes the plain gem (script/platform_release.rb). The task comes from
# bundler/gem_tasks, which loads the gemspec and so runs git, so a child rake
# lists the prerequisites.
class TestReleaseTask < Minitest::Test
  ROOT = File.expand_path("../../..", __dir__)

  def test_should_push_the_platform_gems_before_tagging_the_commit
    assert_includes prerequisites("release:source_control_push"), "release:platform_gems"
  end

  private

  def prerequisites(task)
    output, status = Open3.capture2e(RbConfig.ruby, "-S", "rake", "-P", chdir: ROOT)
    raise "rake -P failed: #{output}" unless status.success?

    output[/^rake #{Regexp.escape(task)}\n((?:    .*\n)*)/, 1].to_s.split
  end
end
