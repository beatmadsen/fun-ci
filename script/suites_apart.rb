# frozen_string_literal: true

# The rule fun-ci's stages keep (design.md, The pipeline): the
# build script writes what the suites need, and the fast and slow suites,
# which run at once in one checkout, never write the same file. For each
# stack with a recorded project, this builds the project once in the
# recording's pinned image, runs each suite on its own from that built state,
# and lists what each wrote or deleted; a path both did is where two suites
# running together clash. Required by script/check_init_templates.rb.

# Each suite runs from the same built tree: a tar of it is restored, mtimes
# and all, before the second. A path is written if it is newer than the mark
# or gone since the build. The sleep keeps a coarse clock from hiding a write.
APART = <<~SH.tr("\n", " ")
  find . -type f | sort > /tmp/built; tar cf /tmp/built.tar .;
  for suite in fast slow; do
  find . -mindepth 1 -delete; tar xpf /tmp/built.tar; touch /tmp/mark; sleep 1;
  ./.fun-ci/$suite.sh > /dev/null 2>&1;
  { find . -type f -newer /tmp/mark; find . -type f | sort | comm -23 /tmp/built -; } | sort -u > /tmp/$suite;
  echo "$suite wrote $(wc -l < /tmp/$suite)";
  done;
  comm -12 /tmp/fast /tmp/slow
SH

# What a tool writes on every run that two of its runs share safely, with
# why, as measured in each recording's image: what either suite writes there
# is not a clash.
SHARED = {
  # Gradle's own state, under the .lock files beside it.
  "gradle" => %r{\A\./\.gradle/},
  # SwiftPM waits: "Another instance of SwiftPM is already running using '.build'".
  "swift-test" => %r{\A\./\.build/},
  # A .pyc is written aside and replaced whole; a torn cache file reads as empty.
  "pytest" => %r{/__pycache__/|\A\./\.pytest_cache/},
  # Read only by `mix test --failed`, which no template runs.
  "exunit" => %r{/\.mix_test_failures\z},
  # ctest's log of its last run, and the timings it orders tests by.
  "gtest" => %r{\A\./build/Testing/Temporary/}
}.freeze

# Recordings whose setup does the build's work, which this leaves to build.sh,
# since a setup that builds the tests would hide a build script that doesn't.
BUILDING_SETUPS = %w[exunit swift-test].freeze

# The first preset of each stack whose fast script runs its tool, whose
# recorded project stands in for the stack.
def suite_stacks
  PresetStacks::STACKS.select { |_, place| place.stage == "fast.sh" }.uniq { |_, place| place.stack }.map(&:first)
end

def apart_recipe(name)
  recipe = stage_recipe(name, "build.sh")
  recipe = recipe.merge("setup" => "true") if BUILDING_SETUPS.include?(name)
  recipe.merge("setup" => "#{recipe.fetch("setup")} && ./.fun-ci/build.sh", "command" => APART)
end

def apart_output(name)
  recipe = apart_recipe(name)
  Dir.mktmpdir do |work|
    write_project(recipe.fetch("files"), work)
    FunCi::Setup::Installer.run(project_root: work, stdout: StringIO.new)
    Dir.mktmpdir { |out| run_output(recipe, work, out) }
  end
end

# What is wrong with each named stack's suites run together; every stack's when none is named.
def apart_reports(names)
  suite_stacks.select { |name| names.empty? || names.include?(name) }.filter_map { |name| check_apart(name) }
end

# What is wrong with the stack's suites run together, or nil after saying they keep apart.
def check_apart(name)
  output = apart_output(name)
  counts, shared = output.lines(chomp: true).partition { |line| line.match?(/\A(fast|slow) wrote \d+\z/) }
  clashes = shared.reject { |path| SHARED[name]&.match?(path) }
  return "#{name}: fast and slow both write\n#{clashes.join("\n")}" unless clashes.empty?

  puts "#{name}: fast and slow write nothing in common (#{counts.join(", ")})"
end
