# frozen_string_literal: true

require_relative "../test_helper"
require "yaml"

# AT-4.2: CI builds the platform gem for each of the five targets
# architecture.md names, installs each into an empty GEM_HOME and runs it,
# and does the same for the plain gem, which has no renderer. AT-4.3: the
# renderer crate packages as crates.io would take it, and a renderer
# installed with cargo is the one the plain gem finds.
class TestGemsWorkflow < Minitest::Test
  WORKFLOW = File.expand_path("../../.github/workflows/gems.yml", __dir__)
  PLATFORMS = %w[aarch64-linux arm64-darwin x86_64-darwin x86_64-linux x86_64-linux-musl].freeze

  def test_should_build_a_gem_for_each_of_the_five_platforms
    assert_equal PLATFORMS, builds.map { |build| build["platform"] }.sort
  end

  def test_should_build_each_platform_gem_with_the_gem_script
    assert(commands("platform").any? { |command| command.include?("script/platform_gem.rb ${{ matrix.platform }}") })
  end

  def test_should_smoke_test_every_platform_gem_it_builds
    smoked = (commands("platform") + commands("musl-smoke")).grep(%r{script/smoke-platform-gem\.sh}).size

    assert_equal 2, smoked
  end

  def test_should_smoke_the_musl_gem_on_a_musl_ruby
    assert_match(/alpine/, jobs.dig("musl-smoke", "container"))
  end

  def test_should_check_the_plain_gem_says_how_to_get_a_renderer
    assert(commands("plain").any? { |command| command.match?(%r{script/smoke-platform-gem\.sh .* none}) })
  end

  def test_should_package_the_renderer_crate_as_crates_io_would_take_it
    assert_includes commands("cargo-install"), "cargo publish --dry-run --locked --manifest-path renderer/Cargo.toml"
  end

  def test_should_find_a_renderer_installed_with_cargo_from_the_plain_gem
    assert(commands("cargo-install").any? { |command| command.match?(%r{script/smoke-platform-gem\.sh .* path}) })
  end

  private

  def workflow = YAML.safe_load_file(WORKFLOW)
  def jobs = workflow.fetch("jobs")
  def builds = jobs.dig("platform", "strategy", "matrix", "include")
  def commands(job) = jobs.dig(job, "steps").filter_map { |step| step["run"] }
end
