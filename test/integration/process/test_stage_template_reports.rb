# frozen_string_literal: true

require_relative "../../test_helper"
require "open3"
require "fun_ci/setup/stage_templates"

# AT-9.8: the fast and slow scripts `fun-ci init` writes for Gradle and Maven
# copy the build's JUnit XML into FUN_CI_REPORT, and exit as the build did.
# Each runs against a stand-in build tool that writes a report and fails.
class TestStageTemplateReports < Minitest::Test
  Case = Data.define(:template, :script, :tool, :report_dir) do
    def name = "#{template}_#{script.delete_suffix(".sh")}"
  end

  CASES = [
    Case.new(:jvm_gradle_kotlin, "fast.sh", "./gradlew", "build/test-results/test"),
    Case.new(:jvm_gradle_kotlin, "slow.sh", "./gradlew", "build/test-results/integrationTest"),
    Case.new(:jvm_gradle_groovy, "fast.sh", "./gradlew", "build/test-results/test"),
    Case.new(:jvm_gradle_groovy, "slow.sh", "./gradlew", "build/test-results/integrationTest"),
    Case.new(:jvm_maven, "fast.sh", "mvn", "target/surefire-reports"),
    Case.new(:jvm_maven, "slow.sh", "mvn", "target/failsafe-reports")
  ].freeze

  def setup
    @project = Dir.mktmpdir("template-project")
    @reports = Dir.mktmpdir("template-reports")
  end

  def teardown = [@project, @reports].each { |dir| FileUtils.rm_rf(dir) }

  CASES.each do |example|
    define_method("test_#{example.name}_copies_the_build_s_report") do
      run_script(example, "FUN_CI_REPORT" => @reports)

      assert_equal ["TEST-Example.xml"], Dir.children(@reports)
    end

    define_method("test_#{example.name}_exits_as_the_build_did") do
      assert_equal 3, run_script(example, "FUN_CI_REPORT" => @reports).exitstatus
    end

    define_method("test_#{example.name}_runs_without_a_report_directory") do
      assert_equal 3, run_script(example, "FUN_CI_REPORT" => nil).exitstatus
    end
  end

  private

  def run_script(example, env)
    bin = install_tool(example)
    path = File.join(@project, example.script)
    File.write(path, FunCi::Setup::StageTemplates.scripts(example.template).fetch(example.script), perm: 0o755)
    Open3.capture2e(env.merge("PATH" => "#{bin}:#{ENV.fetch("PATH")}"), path, chdir: @project).last
  end

  # A build tool that writes one report where the build would, then exits 3.
  def install_tool(example)
    bin = File.join(@project, "bin").tap { |dir| FileUtils.mkdir_p(dir) }
    path = example.tool.start_with?("./") ? File.join(@project, example.tool) : File.join(bin, example.tool)
    report = "#{example.report_dir}/TEST-Example.xml"
    File.write(path, "#!/bin/sh\nmkdir -p #{example.report_dir}\necho '<testsuite/>' > #{report}\nexit 3\n",
               perm: 0o755)
    bin
  end
end
