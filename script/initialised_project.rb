# frozen_string_literal: true

# A preset's recorded failing project as `fun-ci init` sets it up, run in the
# recording's pinned image: what script/check_init_templates.rb checks the
# stage scripts on.
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require_relative "check_evidence_presets"
require "fun_ci/setup/installer"
require "stringio"

COMPOSER = "curl -sS https://getcomposer.org/installer | " \
           "php -- --quiet --install-dir=/usr/local/bin --filename=composer"
PHPUNIT_XML = "<phpunit bootstrap=\"vendor/autoload.php\"><testsuites><testsuite name=\"all\">" \
              "<directory>tests</directory></testsuite></testsuites></phpunit>\n"

# The slow suite the template runs.
GRADLE_ADDITIONS = <<~KTS
  tasks.register<Test>("integrationTest") {
      testClassesDirs = sourceSets.test.get().output.classesDirs
      classpath = sourceSets.test.get().runtimeClasspath
      useJUnitPlatform()
  }
KTS

# What a real project of the stack has that a recording's minimal one leaves
# out: a committed Gradle wrapper, rake in the bundle, Composer and PHPUnit's
# configuration, and a slow test for the slow suite to run (in slow_tests.rb).
# `prepare` stands in for a recording's setup that does the build's work,
# where the build script is under test.
NEEDS = {
  "gradle" => { "setup" => "gradle wrapper -q --no-daemon", "append" => { "build.gradle.kts" => GRADLE_ADDITIONS } },
  "minitest" => {
    "files" => {
      "Gemfile" => "source \"https://rubygems.org\"\ngem \"minitest\", \"5.25.5\"\ngem \"rake\"\n",
      "Rakefile" => "require \"rake/testtask\"\nRake::TestTask.new { |task| task.pattern = \"test/*_test.rb\" }\n"
    }
  },
  "phpunit" => {
    "files" => { "phpunit.xml" => PHPUNIT_XML },
    "setup" => "apt-get update -qq && apt-get install -y -qq unzip && #{COMPOSER}"
  },
  "exunit" => { "prepare" => "true" },
  "swift-test" => { "prepare" => "true" }
}.freeze

require_relative "slow_tests"

# The recording's recipe with the stage as its command, after its setup (and
# the build script, before a test stage, as a pipeline runs it).
def stage_recipe(name, stage)
  recipe = YAML.safe_load_file(File.join(fixture_dir(name), "recipe.yml"))
  need = NEEDS.fetch(name, {})
  build = "./.fun-ci/build.sh" unless %w[lint.sh build.sh].include?(stage)
  setup = [recipe.fetch("setup", "true"), need["setup"], build].compact.join(" && ")
  recipe.merge("setup" => setup, "command" => "./.fun-ci/#{stage}", "version" => "true",
               "files" => project_files(name, recipe.fetch("files"), need))
end

# The recipe with `command` in place of any stage, after a setup that builds nothing.
def unbuilt_recipe(name, command)
  recorded = YAML.safe_load_file(File.join(fixture_dir(name), "recipe.yml")).fetch("setup", "true")
  need = NEEDS.fetch(name, {})
  setup = [need.fetch("prepare", recorded), need["setup"]].compact.join(" && ")
  stage_recipe(name, "lint.sh").merge("setup" => setup, "command" => command)
end

def project_files(name, files, need)
  appended = need.fetch("append", {}).to_h { |path, text| [path, files.fetch(path) + text] }
  files.merge(need.fetch("files", {}), SLOW_TESTS.fetch(name, {}), appended)
end

# What the recipe's command printed in the project `fun-ci init` set up, and its exit status.
def initialised_run(recipe)
  Dir.mktmpdir do |work|
    write_project(recipe.fetch("files"), work)
    FunCi::Setup::Installer.run(project_root: work, stdout: StringIO.new)
    Dir.mktmpdir { |out| [run_output(recipe, work, out), File.read(File.join(out, "status")).to_i] }
  end
end
