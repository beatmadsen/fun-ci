# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/project_detector"

class TestProjectDetector < Minitest::Test
  def test_should_detect_ruby_bundler_when_gemfile_present
    # Given a file list containing Gemfile
    detector = FunCi::Setup::ProjectDetector.new(["Gemfile", "Rakefile", "lib"])

    # When we detect the project type
    result = detector.detect

    # Then it should return ruby_bundler
    assert_equal :ruby_bundler, result, "Should detect Ruby+Bundler from Gemfile"
  end

  def test_should_detect_jvm_gradle_kotlin_when_build_gradle_kts_present
    # Given a file list containing build.gradle.kts (single-module project)
    detector = FunCi::Setup::ProjectDetector.new(["build.gradle.kts", "src"])

    # When we detect the project type
    result = detector.detect

    # Then it should return jvm_gradle_kotlin
    assert_equal :jvm_gradle_kotlin, result, "Should detect Gradle Kotlin from build.gradle.kts"
  end

  def test_should_detect_jvm_gradle_groovy_when_build_gradle_present
    # Given a file list containing build.gradle (single-module Groovy project)
    detector = FunCi::Setup::ProjectDetector.new(["build.gradle", "src"])

    # When we detect the project type
    result = detector.detect

    # Then it should return jvm_gradle_groovy
    assert_equal :jvm_gradle_groovy, result, "Should detect Gradle Groovy from build.gradle"
  end

  def test_should_detect_jvm_gradle_kotlin_from_settings_gradle_kts_alone
    # Given a multi-module project with only settings.gradle.kts at root
    detector = FunCi::Setup::ProjectDetector.new(["settings.gradle.kts", "gradlew", "app"])

    # When we detect the project type
    result = detector.detect

    # Then it should return jvm_gradle_kotlin
    assert_equal :jvm_gradle_kotlin, result, "Should detect Gradle Kotlin from settings.gradle.kts"
  end

  def test_should_detect_jvm_gradle_groovy_from_settings_gradle_alone
    # Given a multi-module project with only settings.gradle at root
    detector = FunCi::Setup::ProjectDetector.new(["settings.gradle", "gradlew", "app"])

    # When we detect the project type
    result = detector.detect

    # Then it should return jvm_gradle_groovy
    assert_equal :jvm_gradle_groovy, result, "Should detect Gradle Groovy from settings.gradle"
  end

  def test_should_detect_jvm_maven_when_pom_xml_present
    # Given a file list containing pom.xml
    detector = FunCi::Setup::ProjectDetector.new(["pom.xml", "src", "target"])

    # When we detect the project type
    result = detector.detect

    # Then it should return jvm_maven
    assert_equal :jvm_maven, result, "Should detect Maven from pom.xml"
  end

  def test_should_return_unknown_when_no_marker_files_present
    # Given a file list with no recognized markers
    detector = FunCi::Setup::ProjectDetector.new(["README.md", "src", "docs"])

    # When we detect the project type
    result = detector.detect

    # Then it should return unknown
    assert_equal :unknown, result, "Should return unknown for unrecognized project"
  end
end

class TestProjectDetectorPriority < Minitest::Test
  def test_should_prefer_ruby_when_gemfile_and_pom_xml_both_present
    # Given a polyglot project with both Gemfile and pom.xml
    detector = FunCi::Setup::ProjectDetector.new(["Gemfile", "pom.xml", "src"])

    # When we detect the project type
    result = detector.detect

    # Then Ruby should take priority
    assert_equal :ruby_bundler, result, "Ruby should take priority over Maven"
  end

  def test_should_prefer_gradle_kotlin_when_both_build_files_present
    # Given a project with both build.gradle.kts and build.gradle
    detector = FunCi::Setup::ProjectDetector.new(["build.gradle.kts", "build.gradle", "src"])

    # When we detect the project type
    result = detector.detect

    # Then Kotlin should take priority
    assert_equal :jvm_gradle_kotlin, result, "Gradle Kotlin should take priority over Groovy"
  end
end
