# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/project_detector"

class TestProjectDetector < Minitest::Test
  def test_should_detect_ruby_bundler_when_gemfile_present
    detector = FunCi::Setup::ProjectDetector.new(%w[Gemfile Rakefile lib])
    result = detector.detect

    assert_equal :ruby_bundler, result, "Should detect Ruby+Bundler from Gemfile"
  end

  def test_should_detect_jvm_gradle_kotlin_when_build_gradle_kts_present
    detector = FunCi::Setup::ProjectDetector.new(["build.gradle.kts", "src"])
    result = detector.detect

    assert_equal :jvm_gradle_kotlin, result, "Should detect Gradle Kotlin from build.gradle.kts"
  end

  def test_should_detect_jvm_gradle_groovy_when_build_gradle_present
    detector = FunCi::Setup::ProjectDetector.new(["build.gradle", "src"])
    result = detector.detect

    assert_equal :jvm_gradle_groovy, result, "Should detect Gradle Groovy from build.gradle"
  end

  def test_should_detect_jvm_gradle_kotlin_from_settings_gradle_kts_alone
    detector = FunCi::Setup::ProjectDetector.new(["settings.gradle.kts", "gradlew", "app"])
    result = detector.detect

    assert_equal :jvm_gradle_kotlin, result, "Should detect Gradle Kotlin from settings.gradle.kts"
  end

  def test_should_detect_jvm_gradle_groovy_from_settings_gradle_alone
    detector = FunCi::Setup::ProjectDetector.new(["settings.gradle", "gradlew", "app"])
    result = detector.detect

    assert_equal :jvm_gradle_groovy, result, "Should detect Gradle Groovy from settings.gradle"
  end

  def test_should_detect_jvm_maven_when_pom_xml_present
    detector = FunCi::Setup::ProjectDetector.new(["pom.xml", "src", "target"])
    result = detector.detect

    assert_equal :jvm_maven, result, "Should detect Maven from pom.xml"
  end

  def test_should_return_unknown_when_no_marker_files_present
    detector = FunCi::Setup::ProjectDetector.new(["README.md", "src", "docs"])
    result = detector.detect

    assert_equal :unknown, result, "Should return unknown for unrecognized project"
  end
end

class TestProjectDetectorPriority < Minitest::Test
  def test_should_prefer_ruby_when_gemfile_and_pom_xml_both_present
    detector = FunCi::Setup::ProjectDetector.new(["Gemfile", "pom.xml", "src"])
    result = detector.detect

    assert_equal :ruby_bundler, result, "Ruby should take priority over Maven"
  end

  def test_should_prefer_gradle_kotlin_when_both_build_files_present
    detector = FunCi::Setup::ProjectDetector.new(["build.gradle.kts", "build.gradle", "src"])
    result = detector.detect

    assert_equal :jvm_gradle_kotlin, result, "Gradle Kotlin should take priority over Groovy"
  end
end
