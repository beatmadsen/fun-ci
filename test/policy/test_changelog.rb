# frozen_string_literal: true

require_relative "../test_helper"

# AT-0.10: the 2.0 breaking changes are announced where upgraders look.
class TestChangelog < Minitest::Test
  CHANGELOG = File.expand_path("../../CHANGELOG.md", __dir__)

  %w[fun-ci-trigger fun-ci-tui].each do |executable|
    define_method(:"test_lists_the_removal_of_#{executable.tr("-", "_")}_as_unreleased") do
      assert_includes unreleased_section("Removed"), "`#{executable}`"
    end
  end

  private

  def unreleased_section(heading)
    unreleased = File.read(CHANGELOG)[/^## \[Unreleased\]\n(.*?)(?=^## \[)/m, 1].to_s
    unreleased[/^### #{heading}\n(.*?)(?=^### |\z)/m, 1].to_s
  end
end
