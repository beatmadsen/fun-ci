# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/installer"
require "tmpdir"
require "stringio"

module InitTemplateContent
  private

  # Runs the real init against a project holding only +marker+ and returns the
  # generated .fun-ci/<script>.
  def generated_script(marker, marker_content, script)
    Dir.mktmpdir("fun-ci-template-test") do |dir|
      File.write(File.join(dir, marker), marker_content)
      FunCi::Setup::Installer.run(project_root: dir, stdout: StringIO.new)
      File.read(File.join(dir, ".fun-ci", script))
    end
  end
end

class TestInitTemplateContentRuby < Minitest::Test
  include InitTemplateContent

  GEMFILE = "source 'https://rubygems.org'\n"

  def test_should_not_pass_commit_hash_to_rubocop_in_lint_script
    content = generated_script("Gemfile", GEMFILE, "lint.sh")
    assert_match(/rubocop/, content, "Should use rubocop")
    refute_match(/rubocop.*\$1/, content, "Should not pass $1 to rubocop")
  end

  def test_should_not_pass_commit_hash_to_bundle_install_in_build_script
    content = generated_script("Gemfile", GEMFILE, "build.sh")
    assert_match(/bundle install/, content, "Should use bundle install")
    refute_match(/\$1/, content, "Should not pass $1 to bundle install")
  end
end

class TestInitTemplateContentGradle < Minitest::Test
  include InitTemplateContent

  BUILD_GRADLE_KTS = "plugins { kotlin(\"jvm\") }\n"

  def test_should_not_pass_commit_hash_to_gradlew_check_in_lint_script
    content = generated_script("build.gradle.kts", BUILD_GRADLE_KTS, "lint.sh")
    assert_match(/gradlew.*check/, content, "Should use gradlew check")
    refute_match(/\$1/, content, "Should not pass $1 to gradlew check")
  end

  def test_should_not_pass_commit_hash_to_gradlew_assemble_in_build_script
    content = generated_script("build.gradle.kts", BUILD_GRADLE_KTS, "build.sh")
    assert_match(/gradlew.*assemble/, content, "Should use gradlew assemble")
    refute_match(/\$1/, content, "Should not pass $1 to gradlew assemble")
  end
end

class TestInitTemplateContentMaven < Minitest::Test
  include InitTemplateContent

  POM = "<project></project>\n"

  POM_WITH_DETEKT = <<~XML
    <project>
      <build><plugins>
        <plugin><artifactId>detekt-maven-plugin</artifactId></plugin>
      </plugins></build>
    </project>
  XML

  def test_should_not_pass_commit_hash_to_mvn_verify_in_lint_script
    content = generated_script("pom.xml", POM, "lint.sh")
    assert_match(/mvn.*verify/, content, "Should use mvn verify")
    refute_match(/\$1/, content, "Should not pass $1 to mvn verify")
  end

  def test_should_not_pass_commit_hash_to_mvn_compile_in_build_script
    content = generated_script("pom.xml", POM, "build.sh")
    assert_match(/mvn.*compile/, content, "Should use mvn compile")
    refute_match(/\$1/, content, "Should not pass $1 to mvn compile")
  end

  def test_should_use_detected_linter_when_pom_contains_linter_plugin
    lint_content = generated_script("pom.xml", POM_WITH_DETEKT, "lint.sh")
    assert_match(/mvn detekt:check/, lint_content, "Should use detected detekt command")
    refute_match(/verify/, lint_content, "Should not contain default mvn verify")
  end
end
