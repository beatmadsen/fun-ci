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

platform, binary, out_dir = ARGV
abort "usage: ruby script/platform_gem.rb <platform> <renderer binary> <out dir>" unless out_dir

root = File.expand_path("..", __dir__)
libexec = File.join(root, "libexec")
FileUtils.mkdir_p(libexec)
FileUtils.install(binary, File.join(libexec, "fun-ci-renderer"), mode: 0o755)

Dir.chdir(root) do
  spec = Gem::Specification.load("fun_ci.gemspec")
  spec.platform = Gem::Platform.new(platform)
  spec.files += ["libexec/fun-ci-renderer"]
  built = Gem::Package.build(spec)
  FileUtils.mkdir_p(out_dir)
  FileUtils.mv(built, out_dir)
  puts File.expand_path(File.join(out_dir, File.basename(built)))
end
