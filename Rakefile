# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"
require "etc"
require_relative "renderer/tools/renderer_build"

# `test` is the gate's lane; the others are quicker subsets of it.
# test/policy/test_gate_lanes.rb holds them to that.
TEST_LANES = {
  "test" => "test/**/test_*.rb",
  "unit" => "test/unit/**/test_*.rb",
  "integration" => "test/integration/**/test_*.rb",
  "acceptance" => "test/acceptance/**/test_*.rb",
  "policy" => "test/policy/**/test_*.rb",
  # The three that start no process, in one process: fun-ci's fast stage here.
  "fast" => "test/{unit,acceptance,policy}/**/test_*.rb"
}.freeze

TEST_LANES.each do |lane, pattern|
  Rake::TestTask.new(lane) do |t|
    t.libs.push("test", "lib")
    t.test_files = FileList[pattern]
  end
end

# Kept out of `rake test`: it needs the binary cargo builds first.
def drive_renderer_binary
  sh "cargo", "build", "--manifest-path", RENDERER_MANIFEST
  binary = File.expand_path("renderer/target/debug/fun-ci-renderer", __dir__)
  sh({ "FUN_CI_RENDERER" => binary }, FileUtils::RUBY, "-Itest", "-Ilib", "contract/binary/test_renderer_binary.rb")
end

namespace :contract do
  desc "Drive the real renderer binary on a pseudo-terminal through the happy-7 contract fixture"
  task(binary: "rust:fresh") { drive_renderer_binary }
end

RuboCop::RakeTask.new

require_relative "test/support/mutation_scope"
MUTATED = MutationScope.sources

# Mutineer runs a mutant's covering tests serially and kills a run that passes
# ten seconds.
MUTATION_TESTS = FileList[TEST_LANES.fetch("test")].exclude("test/test_helper.rb")

def mutineer(*extra)
  tests = MUTATION_TESTS.flat_map { |file| ["--test", file] }
  command = ["bundle", "exec", "mutineer", "run", *MUTATED, *tests, "--strategy", "redefine", *extra]
  sh({ "MUTATION_TESTING" => "1", "RUBYOPT" => "-Ilib -Itest" }, *command, verbose: false)
end

desc "Mutation testing over lib (Ruby >= 3.4); fails below the threshold in .mutineer.yml"
task(:mutation) { mutineer }

namespace :mutation do
  desc "Mutation testing over lines changed since REV (HEAD by default); a prompt to look, not a verdict"
  task(:changed, [:rev]) { |_, args| mutineer("--since", args[:rev] || "HEAD") }
end

RENDERER_MANIFEST = File.expand_path("renderer/Cargo.toml", __dir__)

namespace :release do
  desc "Push the platform gems the Gems workflow built for HEAD; each asks for an MFA code (DRY_RUN=1 only lists them)"
  task(:platform_gems) do
    require_relative "script/platform_release"
    require_relative "lib/fun_ci/version"
    PlatformRelease.push(FunCi::VERSION, `git rev-parse HEAD`.strip, PlatformRelease.pusher(ENV))
  end
end

# `rake release` (bundler/gem_tasks) tags the commit, then pushes the plain
# gem; the platform gems go first, so nobody gets the gem without its renderer.
if Rake::Task.task_defined?("release:source_control_push")
  Rake::Task["release:source_control_push"].enhance(["release:platform_gems"])
end

namespace :rust do
  # The lanes that run the binary test renderer/src (renderer/tools/renderer_build.rb).
  task(:fresh) { (clean = FunCi::RendererBuild.clean_command(RENDERER_MANIFEST)) && sh(*clean) }

  desc "Run the Rust renderer's tests"
  task(test: :fresh) { sh "cargo", "test", "--manifest-path", RENDERER_MANIFEST }

  desc "Lint the Rust renderer with clippy (pedantic, warnings are errors)"
  task(:clippy) { sh "cargo", "clippy", "--manifest-path", RENDERER_MANIFEST, "--all-targets", "--", "-D", "warnings" }
end

RUST_MUTATION_THRESHOLD = 90

MUTANT_SHARDS = File.expand_path("renderer/mutants-shards", __dir__)

def rust_mutation(threshold)
  mutate_renderer(File.expand_path("renderer", __dir__))
  judge_rust_mutation([File.expand_path("renderer/mutants.out/outcomes.json", __dir__)], threshold)
end

# One shard of the mutants, k of n, as CI runs them side by side; judged
# together by mutation:rust:score.
def rust_mutation_shard(shard, shards)
  mutate_renderer(File.join(MUTANT_SHARDS, shard.to_s), "--shard", "#{shard}/#{shards}")
end

def mutate_renderer(out, *shard)
  require_relative "renderer/tools/mutation_score"
  FileUtils.mkdir_p(out)
  status = run_cargo_mutants(out, *shard)
  abort "cargo mutants measured nothing (exit #{status.inspect})" unless FunCi::Mutation.completed?(status)
end

def judge_rust_mutation(outcomes, threshold)
  require_relative "renderer/tools/mutation_score"
  score = FunCi::Mutation::Score.combine(outcomes)
  puts score.summary
  abort "Rust mutation score is under #{threshold}%" unless score.passes?(threshold)
end

def judge_rust_shards(shards, threshold)
  outcomes = Dir.glob(File.join(MUTANT_SHARDS, "**", "outcomes.json"))
  abort "found the outcomes of #{outcomes.size} shards, not #{shards}" unless outcomes.size == Integer(shards)

  judge_rust_mutation(outcomes, threshold)
end

# Tests read the scenarios and fixtures through FUN_CI_CONTRACT, because cargo-mutants
# builds a copy of renderer/ that has no ../contract next to it. The suite takes
# seconds; the fixed timeout is for mutants that make a test wait forever (one
# that stops SIGTERM being handled leaves the pty test waiting for an exit).
def run_cargo_mutants(out, *shard)
  renderer = File.expand_path("renderer", __dir__)
  env = { "FUN_CI_CONTRACT" => File.expand_path("contract", __dir__) }
  jobs = [Etc.nprocessors / 2, 1].max.to_s
  system(env, "cargo", "mutants", "-d", renderer, "-o", out, "-j", jobs, "--timeout", "120", *shard)
  Process.last_status.exitstatus
end

namespace :mutation do
  desc "Mutation-test the Rust renderer with cargo-mutants; fails under 90% of viable mutants caught"
  task(:rust) { rust_mutation(RUST_MUTATION_THRESHOLD) }
end

desc "cargo-mutants on shard k of n of renderer/'s mutants, as CI runs them; judged by mutation:rust:score"
task("mutation:rust:shard", %i[k n]) { |_, args| rust_mutation_shard(Integer(args[:k]), Integer(args[:n])) }

desc "Judge the outcomes of all n shards together against the threshold"
task("mutation:rust:score", %i[n]) { |_, args| judge_rust_shards(args[:n], RUST_MUTATION_THRESHOLD) }

task default: %i[test rust:test contract:binary rubocop rust:clippy]
