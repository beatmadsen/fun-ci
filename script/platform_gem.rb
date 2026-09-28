# frozen_string_literal: true

# Builds the platform gem for one target (architecture.md, Distribution): the
# fun_ci gem as fun_ci.gemspec describes it, for `platform`, with the renderer
# `binary` at libexec/fun-ci-renderer, where Console::RendererLookup looks.
#
#   ruby script/platform_gem.rb x86_64-linux path/to/fun-ci-renderer pkg
#
# Prints the path of the gem it wrote.
require "fileutils"
require "rubygems/package"
require "tmpdir"

platform, binary, out_dir = ARGV
abort "usage: ruby script/platform_gem.rb <platform> <renderer binary> <out dir>" unless out_dir

# The gem is built in a copy of its files, so the renderer never lands in
# this checkout's libexec/, where `exe/fun-ci console` would find it.
root = File.expand_path("..", __dir__)
binary = File.expand_path(binary)
out_dir = File.expand_path(out_dir)
spec = Dir.chdir(root) { Gem::Specification.load("fun_ci.gemspec") }
spec.platform = Gem::Platform.new(platform)

Dir.mktmpdir("fun-ci-platform-gem") do |stage|
  spec.files.each do |file|
    FileUtils.mkdir_p(File.join(stage, File.dirname(file)))
    FileUtils.cp(File.join(root, file), File.join(stage, file))
  end
  FileUtils.mkdir_p(File.join(stage, "libexec"))
  FileUtils.install(binary, File.join(stage, "libexec", "fun-ci-renderer"), mode: 0o755)
  spec.files += ["libexec/fun-ci-renderer"]
  built = Dir.chdir(stage) { Gem::Package.build(spec) }
  FileUtils.mkdir_p(out_dir)
  FileUtils.mv(File.join(stage, built), out_dir)
  puts File.join(out_dir, File.basename(built))
end
