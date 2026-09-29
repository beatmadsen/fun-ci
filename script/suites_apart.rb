# frozen_string_literal: true

# The rule fun-ci's stages keep (design.md, The pipeline): stages that run at
# once write nothing in common. Lint runs beside build on the checkout, and
# the fast suite beside the slow suite on what build made. In a stack's
# recorded project, in its pinned image, SCRIPT runs each of those stages on
# its own from the state it starts from and lists what it wrote or deleted,
# then runs the two suites together once, as a pipeline does; `verdict` reads
# what it printed. script/check_init_templates.rb runs it for each stack.
module SuitesApart
  # A stage runs from a tar of its starting state, restored mtimes and all. A
  # path is written if it is newer than the mark or gone since that state; the
  # sleep keeps a coarse clock from hiding a write. Gradle runs without its
  # daemon, so no stage inherits another's memory of the files.
  SCRIPT = <<~SH.tr("\n", " ")
    export GRADLE_OPTS=-Dorg.gradle.daemon=false;
    restore() { rm -rf ./* ./.[!.]*; tar xpf "$1.tar"; touch /tmp/mark; sleep 1; };
    written() { { find . -type f -newer /tmp/mark; find . -type f | sort | comm -23 "$1" -; } | sort -u; };
    snapshot() { find . -type f | sort > "$1"; tar cf "$1.tar" .; };
    alone() { restore "$2"; ./.fun-ci/$1.sh > /dev/null 2>&1; code=$?; written "$2" > /tmp/$1;
    echo "$1 exit $code wrote $(wc -l < /tmp/$1)"; };
    snapshot /tmp/checkout; alone lint /tmp/checkout; alone build /tmp/checkout;
    echo "== lint/build"; comm -12 /tmp/lint /tmp/build;
    snapshot /tmp/built; restore /tmp/built;
    ./.fun-ci/fast.sh > /tmp/together-fast 2>&1 & fast=$!;
    ./.fun-ci/slow.sh > /tmp/together-slow 2>&1; slow=$?; wait $fast; fast=$?;
    echo "together fast exit $fast"; echo "together slow exit $slow";
    alone fast /tmp/built; alone slow /tmp/built;
    echo "== fast/slow"; comm -12 /tmp/fast /tmp/slow;
    echo "== together fast output"; cat /tmp/together-fast;
    echo "== together slow output"; cat /tmp/together-slow
  SH

  # What a tool writes on every run that two of its runs share safely, with
  # why, as measured in each recording's image: what both stages of a pair
  # write there is not a clash.
  SHARED = {
    # Gradle's own state, under the .lock files beside it.
    "gradle" => %r{\A\./\.gradle/},
    # SwiftPM's plan of the build, rewritten under its lock on .build: the other
    # waits ("Another instance of SwiftPM is already running"), and only while planning.
    "swift-test" => %r{\A\./\.build/(build\.db|debug\.yaml|
                       [^/]+/debug/(description\.json|[^/]+\.build/output-file-map\.json))\z}x,
    # A .pyc is written aside and replaced whole; a torn cache file reads as empty.
    "pytest" => %r{/__pycache__/|\A\./\.pytest_cache/},
    # Read only by `mix test --failed`, which no template runs.
    "exunit" => %r{/\.mix_test_failures\z},
    # ctest's log of its last run, and the timings it orders tests by.
    "gtest" => %r{\A\./build/Testing/Temporary/}
  }.freeze

  # What the slow suite prints once it has run a test, for each stack whose
  # recording has one (its slow test is among the NEEDS of check_init_templates).
  SLOW_RAN = {
    "gradle" => /There were failing tests/,
    "maven" => /Tests run: [1-9]/,
    "dotnet-test" => /Passed:\s+[1-9]/,
    # The recording's four tests left out, and its slow one run.
    "exunit" => /^5 tests, 0 failures, 4 excluded$/,
    "dart-test" => /\+[1-9]\d*: All tests passed/,
    "swift-test" => /Executed [1-9]\d* tests?, with 0 failures/,
    "go-test" => /--- FAIL/,
    "pytest" => /\b[1-9]\d* passed/,
    "rspec" => /\b[1-9]\d* examples?, 0 failures/
  }.freeze

  # Stacks init detects that no recording stands in for, and why that leaves
  # their scripts unmeasured or measured through another's.
  UNMEASURED = {
    jvm_gradle_groovy: "the same scripts as the Kotlin DSL's, which gradle measures",
    python_uv: "pytest through uv; pytest measures the tool, not uv",
    python_poetry: "pytest through poetry; pytest measures the tool, not poetry",
    node_pnpm: "the package's own test scripts through pnpm; nothing compiles",
    node_yarn: "the package's own test scripts through yarn; nothing compiles",
    make: "the Makefile's own targets, which only the project knows"
  }.freeze

  STAGES = %w[lint build fast slow].freeze
  PAIRS = { "lint/build" => "lint and build", "fast/slow" => "fast and slow" }.freeze
  STATUS = /\A(lint|build|fast|slow) exit (\d+) wrote \d+\z/
  MEASURED = /\A(together )?(lint|build|fast|slow) exit \d+/
  NOT_MEASURED = "slow not measured: its recording has no slow test"

  # problems: why the run fails; notes: what it could not measure; measured: each stage's exit and writes.
  Verdict = Data.define(:problems, :notes, :measured)
  Run = Data.define(:exits, :pairs, :fast, :slow)

  # fast_ran: whether the fast suite's output, run beside the slow suite, shows it ran tests.
  def self.verdict(stack, output, fast_ran:)
    run = parse(output)
    Verdict.new(problems: [*missing(run), *failed_build(run), *clashes(stack, run), *idle(stack, run, fast_ran)],
                notes: notes(stack, run), measured: output.lines(chomp: true).grep(MEASURED))
  end

  def self.parse(output)
    head, outputs = output.split("== together fast output\n", 2)
    fast, slow = outputs.to_s.split("== together slow output\n", 2)
    lines = head.lines(chomp: true)
    Run.new(exits: lines.filter_map { STATUS.match(_1)&.captures }.to_h { |stage, code| [stage, code.to_i] },
            pairs: pairs(lines), fast: fast.to_s, slow: slow.to_s)
  end

  def self.pairs(lines)
    sections = lines.slice_before { _1.start_with?("== ") }
    headed = sections.select { _1.first.start_with?("== ") }
    headed.to_h { |header, *rest| [header.delete_prefix("== "), rest.grep(%r{\A\./})] }
  end

  def self.notes(stack, run)
    lint = run.exits.fetch("lint", 0)
    unmeasured_lint = "lint exited #{lint}, so what it writes may not be measured" unless lint.zero?
    [(NOT_MEASURED unless SLOW_RAN.key?(stack)), unmeasured_lint].compact
  end

  def self.missing(run) = (STAGES - run.exits.keys).map { "#{_1} has no measurement" }

  def self.failed_build(run)
    code = run.exits.fetch("build", 0)
    code.zero? ? [] : ["build.sh exited #{code}"]
  end

  def self.clashes(stack, run)
    PAIRS.flat_map { |pair, stages| unshared(stack, run.pairs.fetch(pair, [])).map { "#{stages} both write #{_1}" } }
  end

  def self.unshared(stack, paths) = paths.reject { SHARED[stack]&.match?(_1) }

  def self.idle(stack, run, fast_ran)
    slow_idle = SLOW_RAN.key?(stack) && !SLOW_RAN[stack].match?(run.slow)
    [("fast ran no tests beside slow" unless fast_ran.call(run.fast)), ("slow ran no tests beside fast" if slow_idle)]
      .compact
  end
  private_class_method :parse, :pairs, :notes, :missing, :failed_build, :clashes, :unshared, :idle
end
