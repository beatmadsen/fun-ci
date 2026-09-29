# frozen_string_literal: true

# Records the output of a real failing run of a tool, which pins its preset
# (architecture.md, "Evidence of a failed stage"): the minimal failing project in
# test/fixtures/evidence/NAME/recipe.yml runs in the recipe's pinned Docker
# image (`setup` quietly, then `command`, stdout and stderr merged through a
# pipe as a stage's are, then `version`), and its output is written beside
# the recipe as output.log, with meta.yml saying the tool and its version, the
# image, the command, its exit status, this script's commit and the output's
# SHA-256.
#
#   ruby script/record_evidence_fixture.rb rspec [more names...]
require "digest"
require "fileutils"
require "open3"
require "tmpdir"
require "yaml"

ROOT = File.expand_path("..", __dir__)

def fixture_dir(name) = File.join(ROOT, "test", "fixtures", "evidence", name)

def write_project(files, work)
  files.each do |path, content|
    FileUtils.mkdir_p(File.dirname(File.join(work, path)))
    File.write(File.join(work, path), content)
  end
end

RUN = "(%<setup>s) >/dev/null 2>&1; { (%<command>s) 2>&1; echo $? > /tmp/status; } | cat > /tmp/output; " \
      "(%<version>s) > /tmp/version 2>&1; mkdir -p /out; cp /tmp/status /tmp/output /tmp/version /out/; " \
      "chown -R %<owner>s /work /out"

# The image runs as root; on Linux what it writes into the mounts stays
# root's unless it is handed back, and the host's user can't delete it.
def container_script(recipe, owner)
  format(RUN, setup: recipe.fetch("setup", "true"), command: recipe.fetch("command"),
              version: recipe.fetch("version"), owner: owner)
end

def in_container(recipe, work, out)
  script = container_script(recipe, "#{Process.uid}:#{Process.gid}")
  system("docker", "run", "--rm", "-v", "#{work}:/work", "-v", "#{out}:/out", "-w", "/work", recipe.fetch("image"),
         "sh", "-c", script, exception: true)
end

def record(name)
  recipe = YAML.safe_load_file(File.join(fixture_dir(name), "recipe.yml"))
  Dir.mktmpdir do |work|
    write_project(recipe.fetch("files"), work)
    Dir.mktmpdir { |out| run_recorded(name, recipe, work, out) }
  end
end

def run_recorded(name, recipe, work, out)
  in_container(recipe, work, out)
  read = ->(file) { File.binread(File.join(out, file)) }
  write_fixture(name, recipe, read.call("output"), meta_extras(read.call("status"), read.call("version")))
end

def meta_extras(status, version)
  { "exit_status" => status.to_i, "version" => version.strip.split(/\s*\n\s*/).join("; "),
    "script_commit" => `git -C #{ROOT} rev-parse HEAD`.strip }
end

def meta(recipe, output, extras)
  recipe.slice("tool", "image", "setup", "command").merge("sha256" => Digest::SHA256.hexdigest(output)).merge(extras)
end

def write_fixture(name, recipe, output, extras)
  File.binwrite(File.join(fixture_dir(name), "output.log"), output)
  File.write(File.join(fixture_dir(name), "meta.yml"), meta(recipe, output, extras).to_yaml)
  puts "#{name}: #{output.lines.size} lines, exit #{extras["exit_status"]}, #{extras["version"]}"
end

if $PROGRAM_NAME == __FILE__
  abort "usage: ruby script/record_evidence_fixture.rb NAME..." if ARGV.empty?
  ARGV.each { |name| record(name) }
end
