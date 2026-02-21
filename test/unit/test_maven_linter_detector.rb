# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/maven_linter_detector"

class TestMavenLinterDetectorKnownPlugins < Minitest::Test
  def test_should_detect_detekt_plugin
    # Given a POM containing the detekt plugin
    pom = "<artifactId>detekt-maven-plugin</artifactId>"

    # When we detect the lint command
    result = FunCi::MavenLinterDetector.new(pom).lint_command

    # Then it should return the detekt check command
    assert_equal "mvn detekt:check", result, "Should detect detekt plugin"
  end

  def test_should_detect_ktlint_plugin
    # Given a POM containing the ktlint plugin
    pom = "<artifactId>ktlint-maven-plugin</artifactId>"

    # When we detect the lint command
    result = FunCi::MavenLinterDetector.new(pom).lint_command

    # Then it should return the ktlint check command
    assert_equal "mvn ktlint:check", result, "Should detect ktlint plugin"
  end

  def test_should_detect_checkstyle_plugin
    # Given a POM containing the checkstyle plugin
    pom = "<artifactId>maven-checkstyle-plugin</artifactId>"

    # When we detect the lint command
    result = FunCi::MavenLinterDetector.new(pom).lint_command

    # Then it should return the checkstyle check command
    assert_equal "mvn checkstyle:check", result, "Should detect checkstyle plugin"
  end

  def test_should_detect_spotbugs_plugin
    # Given a POM containing the spotbugs plugin
    pom = "<artifactId>spotbugs-maven-plugin</artifactId>"

    # When we detect the lint command
    result = FunCi::MavenLinterDetector.new(pom).lint_command

    # Then it should return the spotbugs check command
    assert_equal "mvn spotbugs:check", result, "Should detect spotbugs plugin"
  end

  def test_should_detect_pmd_plugin
    # Given a POM containing the PMD plugin
    pom = "<artifactId>maven-pmd-plugin</artifactId>"

    # When we detect the lint command
    result = FunCi::MavenLinterDetector.new(pom).lint_command

    # Then it should return the pmd check command
    assert_equal "mvn pmd:check", result, "Should detect PMD plugin"
  end
end

class TestMavenLinterDetectorFallback < Minitest::Test
  def test_should_return_default_when_no_linter_found
    # Given a POM with no recognized linter plugin
    pom = "<project><artifactId>my-app</artifactId></project>"

    # When we detect the lint command
    result = FunCi::MavenLinterDetector.new(pom).lint_command

    # Then it should fall back to the default
    assert_equal "mvn verify -DskipTests", result, "Should fall back to default when no linter found"
  end

  def test_should_return_default_when_pom_is_empty
    # Given an empty POM string
    # When we detect the lint command
    result = FunCi::MavenLinterDetector.new("").lint_command

    # Then it should fall back to the default
    assert_equal "mvn verify -DskipTests", result, "Should fall back to default for empty POM"
  end
end

class TestMavenLinterDetectorPriority < Minitest::Test
  def test_should_return_first_matching_linter_when_multiple_present
    # Given a POM containing multiple linter plugins
    pom = <<~XML
      <artifactId>detekt-maven-plugin</artifactId>
      <artifactId>maven-checkstyle-plugin</artifactId>
    XML

    # When we detect the lint command
    result = FunCi::MavenLinterDetector.new(pom).lint_command

    # Then it should return the first match
    assert_equal "mvn detekt:check", result, "Should return first matching linter when multiple present"
  end
end
