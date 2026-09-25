# frozen_string_literal: true

require_relative "../test_helper"

# AT-0.10: the 2.0 breaking changes are announced where upgraders look: in
# the 2.0.0 release's section of the changelog.
class TestChangelog < Minitest::Test
  CHANGELOG = File.expand_path("../../CHANGELOG.md", __dir__)

  %w[fun-ci-trigger fun-ci-tui].each do |executable|
    define_method(:"test_lists_the_removal_of_#{executable.tr("-", "_")}_in_2_0_0") do
      assert_includes release_section("2.0.0", "Removed"), "`#{executable}`"
    end
  end

  private

  def release_section(version, heading)
    release = File.read(CHANGELOG)[/^## \[#{Regexp.escape(version)}\][^\n]*\n(.*?)(?=^## \[)/m, 1].to_s
    release[/^### #{heading}\n(.*?)(?=^### |\z)/m, 1].to_s
  end
end
