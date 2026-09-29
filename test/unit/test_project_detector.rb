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

class TestProjectDetectorVariants < Minitest::Test
  def test_should_run_rspec_for_a_bundled_project_with_a_spec_directory
    assert_equal :ruby_rspec, detect(%w[Gemfile spec lib])
  end

  def test_should_not_take_a_spec_directory_without_a_gemfile_for_rspec
    assert_equal :unknown, detect(%w[spec README.md])
  end

  def test_should_detect_dotnet_from_a_solution_file_whatever_its_name
    assert_equal :dotnet, detect(%w[Shop.sln src])
  end

  def test_should_detect_dotnet_from_an_fsharp_project_file
    assert_equal :dotnet, detect(%w[Shop.fsproj Program.fs])
  end

  def test_should_detect_pnpm_from_its_lockfile
    assert_equal :node_pnpm, detect(%w[package.json pnpm-lock.yaml])
  end

  def test_should_detect_yarn_from_its_lockfile
    assert_equal :node_yarn, detect(%w[package.json yarn.lock])
  end

  def test_should_detect_uv_from_its_lockfile
    assert_equal :python_uv, detect(%w[pyproject.toml uv.lock])
  end

  def test_should_detect_poetry_from_its_lockfile
    assert_equal :python_poetry, detect(%w[pyproject.toml poetry.lock])
  end

  def test_should_detect_plain_python_from_a_requirements_file_alone
    assert_equal :python, detect(%w[requirements.txt app.py])
  end

  private

  def detect(entries) = FunCi::Setup::ProjectDetector.new(entries).detect
end

class TestProjectDetectorPrecedence < Minitest::Test
  def test_should_prefer_python_over_the_node_tooling_beside_it
    assert_equal :python, detect(%w[pyproject.toml package.json])
  end

  def test_should_prefer_deno_over_node
    assert_equal :deno, detect(%w[deno.json package.json])
  end

  def test_should_prefer_bun_over_node
    assert_equal :bun, detect(%w[bun.lock package.json])
  end

  def test_should_prefer_a_language_over_the_makefile_that_wraps_it
    assert_equal :go, detect(%w[go.mod Makefile])
  end

  def test_should_prefer_perl_over_the_makefile_its_build_script_writes
    assert_equal :perl, detect(%w[Makefile.PL Makefile])
  end

  def test_should_prefer_cmake_over_a_makefile
    assert_equal :cmake, detect(%w[CMakeLists.txt Makefile])
  end

  private

  def detect(entries) = FunCi::Setup::ProjectDetector.new(entries).detect
end
