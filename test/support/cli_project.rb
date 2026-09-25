# frozen_string_literal: true

require "fun_ci/cli"
require "tmpdir"
require "stringio"
require "fileutils"

# A fresh project directory to run `fun-ci` subcommands in.
module CliProject
  def setup
    @dir = Dir.mktmpdir("fun-ci-cli-test")
    @stdout = StringIO.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def add_gemfile = File.write(File.join(@dir, "Gemfile"), "source 'https://rubygems.org'\n")
  def git_init = system("git", "init", "--quiet", @dir)
  def hook_path(name) = File.join(@dir, ".git", "hooks", name)
  def hook_exists?(name) = File.exist?(hook_path(name))
  def fun_ci_dir_exists? = Dir.exist?(File.join(@dir, ".fun-ci"))

  def run_cli(*args)
    Dir.chdir(@dir) { FunCi::Cli.run(args, stdout: @stdout, stderr: StringIO.new) }
  end
end
