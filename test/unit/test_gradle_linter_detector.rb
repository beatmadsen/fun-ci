# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/gradle_linter_detector"

# The source linter a Gradle build applies, which lint.sh runs: lint runs
# beside the build, so on the source alone (design.md, Stages side by side).
class TestGradleLinterDetector < Minitest::Test
  def test_should_lint_with_ktlint_when_the_build_applies_it
    assert_equal "./gradlew ktlintCheck", lint('id("org.jlleitschuh.gradle.ktlint") version "12.1.1"')
  end

  def test_should_lint_with_spotless_when_the_build_applies_it
    assert_equal "./gradlew spotlessCheck", lint("id 'com.diffplug.spotless' version '6.25.0'")
  end

  def test_should_lint_with_detekt_when_the_build_applies_it
    assert_equal "./gradlew detekt", lint('id("io.gitlab.arturbosch.detekt") version "1.23.7"')
  end

  def test_should_name_no_linter_for_a_build_that_applies_none
    assert_nil lint("plugins { java }")
  end

  private

  def lint(build_file) = FunCi::Setup::GradleLinterDetector.new(build_file).lint_command
end
