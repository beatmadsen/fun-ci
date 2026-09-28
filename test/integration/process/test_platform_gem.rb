# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/gemspec_probe"
require "fileutils"
require "open3"
require "rubygems/package"
require "tmpdir"

# script/platform_gem.rb bundles a renderer into the gem it builds, and leaves
# the checkout it builds from as it was: a renderer left in its libexec/ is
# the one `exe/fun-ci console` would start from then on.
class TestPlatformGem < Minitest::Test
  ROOT = File.expand_path("../../..", __dir__)
  COPIED = %w[fun_ci.gemspec lib exe script CHANGELOG.md LICENSE.txt README.md].freeze

  def setup
    @dir = Dir.mktmpdir("platform-gem")
    FileUtils.cp_r(COPIED.map { |path| File.join(ROOT, path) }, @dir)
    system("git", "init", "-q", @dir, exception: true)
    system("git", "-C", @dir, "add", ".", exception: true)
    @renderer = File.join(@dir, "built-renderer")
    File.write(@renderer, "not really a renderer")
  end

  def teardown = FileUtils.rm_rf(@dir)

  def build
    output, status = Open3.capture2e(GemspecProbe::OUTSIDE_BUNDLER, RbConfig.ruby, "script/platform_gem.rb",
                                     "arm64-darwin", @renderer, File.join(@dir, "pkg"), chdir: @dir)
    raise "the build failed: #{output}" unless status.success?

    output.lines.last.strip
  end

  def test_should_bundle_the_renderer_at_libexec_fun_ci_renderer
    assert_includes Gem::Package.new(build).spec.files, "libexec/fun-ci-renderer"
  end

  def test_should_leave_no_renderer_in_the_checkout_it_builds_from
    build

    refute_path_exists File.join(@dir, "libexec")
  end
end
