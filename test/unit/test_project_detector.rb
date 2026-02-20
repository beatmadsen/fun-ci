# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/project_detector"

class TestProjectDetector < Minitest::Test
  def test_should_detect_ruby_bundler_when_gemfile_present
    # Given a file list containing Gemfile
    detector = FunCi::ProjectDetector.new(["Gemfile", "Rakefile", "lib"])

    # When we detect the project type
    result = detector.detect

    # Then it should return ruby_bundler
    assert_equal :ruby_bundler, result, "Should detect Ruby+Bundler from Gemfile"
  end

  def test_should_return_unknown_when_no_marker_files_present
    # Given a file list with no recognized markers
    detector = FunCi::ProjectDetector.new(["README.md", "src", "docs"])

    # When we detect the project type
    result = detector.detect

    # Then it should return unknown
    assert_equal :unknown, result, "Should return unknown for unrecognized project"
  end
end
