# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../script/platform_release"

# What `rake release` pushes before the tag and the plain gem: the platform
# gems the Gems workflow built for the commit, one for each platform it builds.
class TestPlatformRelease < Minitest::Test
  WORKFLOW = <<~YAML
    jobs:
      platform:
        strategy:
          matrix:
            include:
              - { platform: x86_64-linux, target: x86_64-unknown-linux-gnu }
              - { platform: arm64-darwin, target: aarch64-apple-darwin }
  YAML
  PLATFORMS = %w[x86_64-linux arm64-darwin].freeze
  BUILT = ["pkg/gem-x86_64-linux/fun_ci-2.0.0-x86_64-linux.gem", "pkg/gem-arm64-darwin/fun_ci-2.0.0-arm64-darwin.gem"]
          .freeze

  def test_should_take_the_platforms_the_gems_workflow_builds
    assert_equal PLATFORMS, PlatformRelease.platforms(WORKFLOW)
  end

  def test_should_name_a_platform_gem_the_download_lacks
    assert_equal ["fun_ci-2.0.0-arm64-darwin.gem"], PlatformRelease.missing(BUILT.first(1), "2.0.0", PLATFORMS)
  end

  def test_should_lack_nothing_when_every_platform_s_gem_is_there
    assert_empty PlatformRelease.missing(BUILT, "2.0.0", PLATFORMS)
  end

  def test_should_download_from_the_run_that_succeeded
    runs = [{ "databaseId" => 7, "conclusion" => "failure" }, { "databaseId" => 9, "conclusion" => "success" }]

    assert_equal 9, PlatformRelease.run_id(runs)
  end

  def test_should_stop_when_no_run_for_the_commit_succeeded
    error = assert_raises(PlatformRelease::NotReady) { PlatformRelease.run_id([{ "databaseId" => 7, "conclusion" => "" }]) }

    assert_includes error.message, "no successful Gems run"
  end

  def test_should_hand_each_gem_rubygems_lacks_to_the_pusher
    pushed = []
    PlatformRelease.publish(BUILT, [{ "number" => "2.0.0", "platform" => "x86_64-linux" }], ->(file) { pushed << file })

    assert_equal BUILT.last(1), pushed
  end

  def test_should_only_list_the_gems_on_a_dry_run
    assert_same PlatformRelease::DRY_RUN, PlatformRelease.pusher({ "DRY_RUN" => "1" })
  end

  def test_should_push_with_gem_otherwise
    assert_same PlatformRelease::GEM_PUSH, PlatformRelease.pusher({})
  end

  def test_should_leave_out_a_gem_rubygems_has_already
    published = [{ "number" => "2.0.0", "platform" => "x86_64-linux" }, { "number" => "1.2.1", "platform" => "ruby" }]

    assert_equal BUILT.last(1), PlatformRelease.unpublished(BUILT, published)
  end
end
