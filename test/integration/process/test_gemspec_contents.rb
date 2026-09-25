# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/gemspec_probe"
require "tmpdir"
require "fileutils"

# AT-0.8: the gem ships exactly the tracked runtime files, and its
# publishing settings, which nothing else in the suite touches, stay put.
class TestGemspecContents < Minitest::Test
  ROOT = File.expand_path("../../..", __dir__)
  SPEC = GemspecProbe.load(File.join(ROOT, "fun_ci.gemspec"))
  DOCUMENTS = %w[CHANGELOG.md LICENSE.txt README.md].freeze
  NOT_RUNTIME = %r{\A(test|features|docs|ralph|contract|script|renderer)/|\A\.|\ACLAUDE\.md\z}

  def test_ships_no_tests_docs_tooling_or_dotfiles
    assert_empty SPEC["files"].grep(NOT_RUNTIME)
  end

  def test_ships_only_lib_exe_and_the_three_documents
    assert_empty(SPEC["files"].reject { |path| path.start_with?("lib/", "exe/") || DOCUMENTS.include?(path) })
  end

  # The repository itself is off limits to git in tests, so these two build a
  # copy in a temporary one.
  def test_ships_every_tracked_file_under_lib_and_exe_and_the_three_documents
    in_repository_copy do |dir|
      tracked, = Open3.capture2("git", "ls-files", "--", "lib", "exe", chdir: dir)

      assert_equal (tracked.lines(chomp: true) + DOCUMENTS).sort, spec_files(dir).sort
    end
  end

  def test_leaves_out_a_file_git_does_not_track
    in_repository_copy do |dir|
      File.write(File.join(dir, "lib", "stray.rb"), "")

      refute_includes spec_files(dir), "lib/stray.rb"
    end
  end

  def test_requires_multi_factor_auth_to_publish
    assert_equal "true", SPEC.dig("metadata", "rubygems_mfa_required")
  end

  %w[homepage_uri source_code_uri changelog_uri bug_tracker_uri documentation_uri].each do |key|
    define_method(:"test_points_#{key}_at_the_repository") do
      assert_match %r{\Ahttps://github\.com/beatmadsen/fun-ci}, SPEC.dig("metadata", key)
    end
  end

  private

  def spec_files(dir) = GemspecProbe.load(File.join(dir, "fun_ci.gemspec"))["files"]

  def in_repository_copy
    Dir.mktmpdir("gemspec") do |dir|
      FileUtils.cp_r(["fun_ci.gemspec", "lib", "exe", *DOCUMENTS].map { |path| File.join(ROOT, path) }, dir)
      system("git", "init", "-q", dir, exception: true)
      system("git", "-C", dir, "add", ".", exception: true)
      yield dir
    end
  end
end
