# frozen_string_literal: true

require_relative "../test_helper"

# Publishing settings are easy to lose in a gemspec edit and nothing else in the
# suite touches them, so they are stated here.
class TestGemspecMetadata < Minitest::Test
  def test_requires_multi_factor_auth_to_publish
    assert_equal "true", spec.metadata["rubygems_mfa_required"]
  end

  def test_points_at_the_repository_for_source_changelog_and_issues
    %w[homepage_uri source_code_uri changelog_uri bug_tracker_uri documentation_uri].each do |key|
      assert_match %r{\Ahttps://github\.com/beatmadsen/fun-ci}, spec.metadata[key].to_s, key
    end
  end

  private

  def spec
    @spec ||= Gem::Specification.load(File.expand_path("../../fun_ci.gemspec", __dir__))
  end
end
