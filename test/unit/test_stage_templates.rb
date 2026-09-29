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
    jvm_maven: "mvn test",
    rust_cargo: "cargo test",
    go: "go test -short ./...",
    elixir_mix: "mix test --exclude slow",
    dart: "dart test --exclude-tags slow",
    swift: "swift test --skip Slow",
    php_composer: "vendor/bin/phpunit --exclude-group slow",
    dotnet: "dotnet test --filter \"Category!=Slow\"",
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
      assert_equal command, FunCi::Setup::StageTemplates.scripts(template)["fast.sh"].lines[1].chomp
    end
  end

  def test_should_make_each_stage_s_command_a_shell_script_of_its_own
    assert_equal({ "lint.sh" => "#!/bin/sh\nl\n", "build.sh" => "#!/bin/sh\nb\n",
                   "fast.sh" => "#!/bin/sh\nf\n", "slow.sh" => "#!/bin/sh\ns\n" },
                 FunCi::Setup::StageTemplates.stages("l", "b", "f", "s"))
  end

  def test_should_copy_the_reports_of_every_directory_a_reporting_command_names
    assert_includes FunCi::Setup::StageTemplates.reporting("mvn verify", "a", "b"), "cp a/*.xml b/*.xml "
  end

  def test_should_let_a_lint_override_replace_the_lint_script
    assert_equal "#!/bin/sh\nmvn detekt:check\n",
                 FunCi::Setup::StageTemplates.scripts(:jvm_maven, lint_override: "mvn detekt:check")["lint.sh"]
  end

  def test_should_keep_the_other_scripts_under_a_lint_override
    assert_equal "#!/bin/sh\nmvn compile\n",
                 FunCi::Setup::StageTemplates.scripts(:jvm_maven, lint_override: "mvn detekt:check")["build.sh"]
  end
end
