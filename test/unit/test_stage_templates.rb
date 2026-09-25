# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/setup/stage_templates"

# The stage scripts `fun-ci init` writes for each kind of project.
class TestStageTemplates < Minitest::Test
  FAST_SUITES = {
    ruby_bundler: "bundle exec rake test",
    jvm_gradle_kotlin: "./gradlew test",
    jvm_gradle_groovy: "./gradlew test",
    jvm_maven: "mvn test"
  }.freeze

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
      assert_equal "#!/bin/sh\n#{command}\n", FunCi::Setup::StageTemplates.scripts(template)["fast.sh"]
    end
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
