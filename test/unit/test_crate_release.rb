# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../script/crate_release"

# What `rake release` publishes to crates.io before the tag: the renderer
# crate, at the version renderer/Cargo.toml gives, unless crates.io has it.
class TestCrateRelease < Minitest::Test
  MANIFEST = <<~TOML
    [dependencies.serde]
    version = "1.0.229"

    [package]
    name = "fun-ci-renderer"
    version = "2.1.0"
  TOML

  def test_should_take_the_version_of_the_package_not_of_a_dependency
    assert_equal "2.1.0", CrateRelease.version(MANIFEST)
  end

  def test_should_read_the_versions_crates_io_lists
    assert_equal %w[2.1.0 2.0.0], CrateRelease.published(%({"versions": [{"num": "2.1.0"}, {"num": "2.0.0"}]}))
  end

  def test_should_read_no_versions_for_a_crate_crates_io_does_not_know
    assert_empty CrateRelease.published(%({"errors": [{"detail": "crate `fun-ci-renderer` does not exist"}]}))
  end

  def test_should_hand_a_version_crates_io_lacks_to_the_publisher
    published = []
    CrateRelease.publish("2.1.0", %w[2.0.0], ->(version) { published << version })

    assert_equal %w[2.1.0], published
  end

  def test_should_leave_out_a_version_crates_io_has_already
    published = []
    CrateRelease.publish("2.0.0", %w[2.0.0], ->(version) { published << version })

    assert_empty published
  end

  def test_should_only_say_what_it_would_publish_on_a_dry_run
    assert_same CrateRelease::DRY_RUN, CrateRelease.publisher({ "DRY_RUN" => "1" })
  end

  def test_should_publish_with_cargo_otherwise
    assert_same CrateRelease::CARGO_PUBLISH, CrateRelease.publisher({})
  end
end
