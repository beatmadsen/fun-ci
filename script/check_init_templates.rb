# frozen_string_literal: true

# The half of AT-10.21 outside the gate. For each preset whose tool one of its
# stack's stage scripts runs, `fun-ci init` sets up the preset's recorded
# failing project, and that script, run in the recording's pinned image after
# the recipe's setup (and the build script before a test stage, as a pipeline
# runs it), must fail printing what the preset picks out. Then, for each stack,
# its fast and slow suites must write nothing in common once built
# (suites_apart.rb). Needs Docker and the network; the weekly evidence
# workflow runs it.
#
#   ruby script/check_init_templates.rb [PRESET...]
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require_relative "check_evidence_presets"
require_relative "../test/support/preset_stacks"
require_relative "suites_apart"
require "fun_ci/setup/installer"
require "stringio"

COMPOSER = "curl -sS https://getcomposer.org/installer | " \
           "php -- --quiet --install-dir=/usr/local/bin --filename=composer"
PHPUNIT_XML = "<phpunit bootstrap=\"vendor/autoload.php\"><testsuites><testsuite name=\"all\">" \
              "<directory>tests</directory></testsuite></testsuites></phpunit>\n"

INTEGRATION_TEST = <<~KTS
  tasks.register<Test>("integrationTest") {
      testClassesDirs = sourceSets.test.get().output.classesDirs
      classpath = sourceSets.test.get().runtimeClasspath
      useJUnitPlatform()
  }
KTS

# What a real project of the stack has that a recording's minimal one leaves
# out: a committed Gradle wrapper and the slow suite the template runs, rake
# in the bundle, Composer and PHPUnit's configuration.
NEEDS = {
  "gradle" => { "setup" => "gradle wrapper -q --no-daemon", "append" => { "build.gradle.kts" => INTEGRATION_TEST } },
  "minitest" => {
    "files" => {
      "Gemfile" => "source \"https://rubygems.org\"\ngem \"minitest\", \"5.25.5\"\ngem \"rake\"\n",
      "Rakefile" => "require \"rake/testtask\"\nRake::TestTask.new { |task| task.pattern = \"test/*_test.rb\" }\n"
    }
  },
  "phpunit" => {
    "files" => { "phpunit.xml" => PHPUNIT_XML },
    "setup" => "apt-get update -qq && apt-get install -y -qq unzip && #{COMPOSER}"
  }
}.freeze

def stage_recipe(name, stage)
  recipe = YAML.safe_load_file(File.join(fixture_dir(name), "recipe.yml"))
  need = NEEDS.fetch(name, {})
  build = "./.fun-ci/build.sh" unless %w[lint.sh build.sh].include?(stage)
  setup = [recipe.fetch("setup", "true"), need["setup"], build].compact.join(" && ")
  recipe.merge("setup" => setup, "command" => "./.fun-ci/#{stage}", "version" => "true",
               "files" => project_files(recipe.fetch("files"), need))
end

def project_files(files, need)
  appended = need.fetch("append", {}).to_h { |path, text| [path, files.fetch(path) + text] }
  files.merge(need.fetch("files", {})).merge(appended)
end

def stage_output(name, stage)
  recipe = stage_recipe(name, stage)
  Dir.mktmpdir do |work|
    write_project(recipe.fetch("files"), work)
    FunCi::Setup::Installer.run(project_root: work, stdout: StringIO.new)
    Dir.mktmpdir { |out| [run_output(recipe, work, out), File.read(File.join(out, "status")).to_i] }
  end
end

# What is wrong with the preset's stack's script, or nil after saying it is right.
def check_template(preset, stage)
  output, status = stage_output(preset.name, stage)
  return "#{preset.name}: #{stage} passed\n#{output}" if status.zero?
  return "#{preset.name}: #{stage} printed no #{preset.name} signature\n#{output}" unless signed?(preset, output)
  return "#{preset.name}: picks out nothing of #{stage}\n#{output}" if picked(preset, output).empty?

  puts "#{preset.name}: #{stage} fails as #{preset.name} reads it"
end

if $PROGRAM_NAME == __FILE__
  placed = PresetStacks::STACKS.select { |name, place| place.stage && (ARGV.empty? || ARGV.include?(name)) }
  broken = placed.filter_map { |name, place| check_template(FunCi::Evidence::Presets.fetch(name), place.stage) }
  broken += apart_reports(ARGV)
  broken.each { |report| puts report }
  exit(broken.empty? ? 0 : 1)
end
