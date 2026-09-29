# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/stage_templates"
require "fun_ci/setup/project_detector"

# The stage scripts `fun-ci init` writes for each kind of project.
class TestStageTemplates < Minitest::Test
  FAST_SUITES = {
    ruby_rspec: "bundle exec rspec --tag ~slow",
    ruby_bundler: "bundle exec rake test",
    jvm_gradle_kotlin: "./gradlew test",
    jvm_gradle_groovy: "./gradlew test",
    jvm_maven: "mvn surefire:test",
    rust_cargo: "cargo test",
    go: "go test -short ./...",
    elixir_mix: "mix test --exclude slow",
    dart: "dart test --exclude-tags slow",
    swift: "swift test --skip-build --skip Slow",
    php_composer: "vendor/bin/phpunit --exclude-group slow",
    dotnet: "dotnet test --no-build --filter \"Category!=Slow\"",
    python_uv: "uv run pytest -m \"not slow\"",
    python_poetry: "poetry run pytest -m \"not slow\"",
    python: "python3 -m pytest -m \"not slow\"",
    deno: "deno test",
    bun: "bun test",
    node_pnpm: "pnpm test",
    node_yarn: "yarn test",
    node_npm: "npm test",
    perl: "prove -lr t",
    cmake: "ctest --test-dir build --output-on-failure --no-tests=error -LE slow",
    make: "make test"
  }.freeze

  # The suites run at once on what build.sh built, so where a tool would
  # compile test code as it tests, the build compiles it and the suites don't
  # (design.md, The pipeline; script/suites_apart.rb checks it in each image).
  TEST_CODE_BUILDS = {
    jvm_gradle_kotlin: "./gradlew assemble testClasses",
    jvm_gradle_groovy: "./gradlew assemble testClasses",
    jvm_maven: "mvn test-compile",
    elixir_mix: "mix deps.get && MIX_ENV=test mix compile",
    dart: "dart pub get --precompile",
    swift: "swift build --build-tests"
  }.freeze

  SLOW_SUITES_THAT_BUILD_NOTHING = {
    jvm_maven: "mvn failsafe:integration-test failsafe:verify",
    dart: "dart test --compiler source --tags slow",
    swift: "swift test --skip-build --filter Slow",
    dotnet: "dotnet test --no-build --filter \"Category=Slow\""
  }.freeze

  # Lint runs beside the build, so it reads the source alone (design.md,
  # Stages side by side): where a tool's usual lint compiles, init's doesn't.
  SOURCE_ONLY_LINTS = {
    jvm_maven: "mvn validate",
    dotnet: "dotnet format whitespace --folder --verify-no-changes",
    jvm_gradle_kotlin: 'echo "No source linter in the build: put ktlint, spotless or detekt in .fun-ci/lint.sh"',
    jvm_gradle_groovy: 'echo "No source linter in the build: put ktlint, spotless or detekt in .fun-ci/lint.sh"'
  }.freeze

  SOURCE_ONLY_LINTS.each do |template, command|
    define_method(:"test_should_lint_#{template}_without_compiling") do
      assert_equal command, command_in(template, "lint.sh")
    end
  end

  TEST_CODE_BUILDS.each do |template, command|
    define_method(:"test_should_compile_#{template}_test_code_in_the_build_script") do
      assert_equal command, command_in(template, "build.sh")
    end
  end

  SLOW_SUITES_THAT_BUILD_NOTHING.each do |template, command|
    define_method(:"test_should_run_the_#{template}_slow_suite_without_building") do
      assert_equal command, command_in(template, "slow.sh")
    end
  end

  def test_should_have_a_template_for_every_stack_init_detects
    assert_equal FunCi::Setup::ProjectDetector::STACKS.keys.sort, FunCi::Setup::StageTemplates::TEMPLATES.keys.sort
  end

  FAST_SUITES.each do |template, command|
    define_method(:"test_should_give_#{template}_all_four_stage_scripts") do
      assert_equal %w[build.sh fast.sh lint.sh slow.sh], FunCi::Setup::StageTemplates.scripts(template).keys.sort
    end

    define_method(:"test_should_make_every_#{template}_script_a_shell_script") do
      assert_empty FunCi::Setup::StageTemplates.scripts(template).values.grep_v(%r{\A#!/bin/sh\n})
    end

    # The tools the scripts call (rubocop, rake, gradlew, mvn) take no commit hash.
    define_method(:"test_should_not_pass_the_commit_hash_on_in_any_#{template}_script") do
      assert_empty FunCi::Setup::StageTemplates.scripts(template).values.grep(/\$1/)
    end

    define_method(:"test_should_run_the_#{template}_fast_suite_with_its_own_tool") do
      assert_equal command, command_in(template, "fast.sh")
    end
  end

  def test_should_make_each_stage_s_command_a_shell_script_of_its_own
    assert_equal({ "lint.sh" => "l", "build.sh" => "b", "fast.sh" => "f", "slow.sh" => "s" },
                 FunCi::Setup::StageTemplates.stages("l", "b", "f", "s").transform_values { _1.lines.last.chomp })
  end

  def test_should_say_in_each_script_which_stage_it_runs_beside
    assert_equal({ "lint.sh" => "# Runs beside build.sh, so it reads the source alone.",
                   "build.sh" => "# Runs beside lint.sh; then fast.sh and slow.sh run side by side on what it builds.",
                   "fast.sh" => "# Runs beside slow.sh, on what build.sh built.",
                   "slow.sh" => "# Runs beside fast.sh, on what build.sh built." },
                 FunCi::Setup::StageTemplates.scripts(:go).transform_values { _1.lines[1].chomp })
  end

  def test_should_say_which_stage_a_lint_override_runs_beside
    assert_equal "#!/bin/sh\n# Runs beside build.sh, so it reads the source alone.\nmvn detekt:check\n",
                 FunCi::Setup::StageTemplates.scripts(:jvm_maven, lint_override: "mvn detekt:check")["lint.sh"]
  end

  def test_should_keep_the_other_scripts_under_a_lint_override
    assert_equal "mvn test-compile", command_in(:jvm_maven, "build.sh", lint_override: "mvn detekt:check")
  end

  private

  def command_in(template, script, lint_override: nil)
    FunCi::Setup::StageTemplates.scripts(template, lint_override: lint_override)[script].lines.last.chomp
  end
end
