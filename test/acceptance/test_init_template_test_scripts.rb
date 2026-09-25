# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/installer"
require "tmpdir"
require "stringio"

# The generated test scripts must not forward $1: the pipeline passes the commit
# hash, and none of these test runners accepts one.
module GeneratedScript
  def generated_script(build_file, build_content, script)
    Dir.mktmpdir("fun-ci-template-test") do |dir|
      File.write(File.join(dir, build_file), build_content)
      FunCi::Setup::Installer.run(project_root: dir, stdout: StringIO.new)
      File.read(File.join(dir, ".fun-ci", script))
    end
  end
end

class TestInitTemplateTestScriptsRuby < Minitest::Test
  include GeneratedScript

  GEMFILE = "source 'https://rubygems.org'\n"

  def test_should_not_pass_commit_hash_to_rake_test_in_fast_script
    content = generated_script("Gemfile", GEMFILE, "fast.sh")
    assert_match(/rake test/, content, "Should use rake test")
    refute_match(/\$1/, content, "Should not pass $1 to rake test")
  end

  def test_should_not_pass_commit_hash_to_rake_test_slow_in_slow_script
    content = generated_script("Gemfile", GEMFILE, "slow.sh")
    assert_match(/rake test/, content, "Should use rake test")
    refute_match(/\$1/, content, "Should not pass $1 to rake test:slow")
  end
end

class TestInitTemplateTestScriptsGradle < Minitest::Test
  include GeneratedScript

  BUILD_FILE = "plugins { kotlin(\"jvm\") }\n"

  def test_should_not_pass_commit_hash_to_gradlew_test_in_fast_script
    content = generated_script("build.gradle.kts", BUILD_FILE, "fast.sh")
    assert_match(/gradlew.*test/, content, "Should use gradlew test")
    refute_match(/\$1/, content, "Should not pass $1 to gradlew test")
  end

  def test_should_not_pass_commit_hash_to_gradlew_integration_test_in_slow_script
    content = generated_script("build.gradle.kts", BUILD_FILE, "slow.sh")
    assert_match(/gradlew.*integrationTest/, content, "Should use gradlew integrationTest")
    refute_match(/\$1/, content, "Should not pass $1 to gradlew integrationTest")
  end
end

class TestInitTemplateTestScriptsMaven < Minitest::Test
  include GeneratedScript

  POM = "<project></project>\n"

  def test_should_not_pass_commit_hash_to_mvn_test_in_fast_script
    content = generated_script("pom.xml", POM, "fast.sh")
    assert_match(/mvn.*test/, content, "Should use mvn test")
    refute_match(/\$1/, content, "Should not pass $1 to mvn test")
  end

  def test_should_not_pass_commit_hash_to_mvn_verify_in_slow_script
    content = generated_script("pom.xml", POM, "slow.sh")
    assert_match(/mvn.*verify/, content, "Should use mvn verify")
    refute_match(/\$1/, content, "Should not pass $1 to mvn verify")
  end
end
