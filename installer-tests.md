# Test Strategy: Smart Installer Features

Test strategy for `fun-ci init`, `fun-ci install-hook`, and `fun-ci check`.
Written before any production code, to guide implementation via ATDD.

---

## I/O Inventory: Where the Side Effects Live

Each feature touches the outside world in specific ways. Identifying these
up front tells us where DI seams are needed and where tests become fragile.

| Feature         | Filesystem reads           | Filesystem writes              | Git commands          | Shell/terminal     |
|-----------------|----------------------------|--------------------------------|-----------------------|--------------------|
| `init`          | Detect Gemfile, build.gradle, pom.xml | Create `.fun-ci/`, write 4 scripts, chmod +x | None                  | stdout messages    |
| `install-hook`  | Read `.git/hooks/<hook>`   | Write `.git/hooks/<hook>`, chmod +x | None (but needs `.git/` to exist) | stdout messages    |
| `check`         | Read `.fun-ci/` contents, `.git/hooks/` | None                           | None                  | stdout messages    |

All three features are filesystem-heavy with no database, no background
processes, and no network. This is a very different profile from Trigger
(which needs `command_runner`, `background_launcher`, and `recorder` seams).
The primary DI seam here is the filesystem itself, and tmpdir is the
right isolation mechanism.

---

## Feature 1: `fun-ci init`

### What It Does

1. Detects the project's language/build system by looking for marker files
   (Gemfile, build.gradle, build.gradle.kts, pom.xml).
2. Creates `.fun-ci/` directory.
3. Writes four scripts (lint.sh, build.sh, fast.sh, slow.sh) with real,
   working commands appropriate for the detected stack.
4. Makes all four scripts executable.

### Natural Decomposition

This feature has two distinct responsibilities that should be separate classes:

**ProjectDetector** -- Pure logic, no I/O. Given a list of filenames
present in a directory, returns a symbol like `:ruby_bundler`,
`:jvm_gradle_kotlin`, `:jvm_gradle_groovy`, `:jvm_maven`, or `:unknown`.

**TemplateWriter** -- Writes files. Given a template identifier and a
target directory, creates `.fun-ci/` and writes the four scripts. Depends
on a template registry (hash of identifier to script contents).

**Installer** (orchestrator) -- Ties them together. Calls the detector,
passes the result to the writer, reports to stdout. This is the class
that `fun-ci init` invokes.

### Unit Tests: ProjectDetector

Pure function, no I/O, no DI needed. These are the easiest tests in the
whole feature.

```
test_should_detect_ruby_bundler_when_gemfile_present
test_should_detect_jvm_gradle_kotlin_when_build_gradle_kts_present
test_should_detect_jvm_gradle_groovy_when_build_gradle_present
test_should_detect_jvm_maven_when_pom_xml_present
test_should_return_unknown_when_no_marker_files_present
```

**DI seam**: The detector should accept a list of filenames (or a lambda
that returns them), NOT scan the filesystem directly. This keeps it pure.
The caller does `Dir.children(project_root)` and passes the result in.

```ruby
# Production
detector = ProjectDetector.new(Dir.children(project_root))

# Test -- no tmpdir needed
detector = ProjectDetector.new(["Gemfile", "Rakefile", "lib"])
assert_equal :ruby_bundler, detector.detect
```

**Pitfall: Priority when multiple markers exist.** A project could have
both `Gemfile` and `pom.xml` (e.g., a polyglot repo). The detector needs
a priority order, and we need a test for the ambiguous case. Better to
test this explicitly than discover it in production.

**Pitfall: Gradle flavor detection.** `build.gradle` (Groovy) vs
`build.gradle.kts` (Kotlin). If both exist, Kotlin should win (`.kts` is
the newer convention). Need a test for this edge case.

### Unit Tests: TemplateWriter

This is where we need tmpdir. The writer creates files, and we verify
their existence, permissions, and content.

```
test_should_create_fun_ci_directory
test_should_create_all_four_scripts
test_should_make_scripts_executable
test_should_write_ruby_bundler_template_when_requested
test_should_write_jvm_gradle_kotlin_template_when_requested
test_should_not_overwrite_existing_fun_ci_directory
```

**How to assert on template content without coupling to exact text:**

Do NOT assert on the full file contents. That makes tests break every
time someone improves a comment. Instead, assert on structural properties:

```ruby
# Good: structural assertions
content = File.read(File.join(dir, ".fun-ci", "fast.sh"))
assert content.start_with?("#!/bin/sh"), "Should have shebang"
assert_match(/bundle exec/, content, "Ruby template should use bundler")
assert_match(/rake/, content, "Ruby template should use rake for tests")
```

```ruby
# Bad: exact content match (fragile)
assert_equal EXPECTED_FAST_SH_CONTENT, File.read(fast_sh_path)
```

The key structural properties to verify per template:
- Shebang line (`#!/bin/sh` or `#!/usr/bin/env bash`)
- The actual tool invocation (bundle exec, ./gradlew, mvn)
- That the script references `$1` (the commit hash argument)

**Pitfall: File.executable? is platform-dependent.** On macOS this works
fine. On CI with different umasks it could be flaky. Use
`File.stat(path).mode & 0o111 != 0` for a more robust executable check,
or just trust `File.chmod(0o755, path)` and test that chmod was called
with the right mode. Since this project already uses `File.chmod(0o755)`
in `FunCiTestProject#make_project_with_scripts` and the integration
`test_project_config.rb` tests, the pattern is proven safe.

**Pitfall: Refusing to overwrite.** If `.fun-ci/` already exists, `init`
should refuse (or prompt). This is important because a user who runs
`init` twice should not lose their customized scripts. Test this case
explicitly.

### Unit Tests: Installer (Orchestrator)

The orchestrator is thin glue. It should be testable with fakes for the
detector and writer, asserting only that it wires them correctly.

```
test_should_report_detected_language_to_stdout
test_should_refuse_when_fun_ci_directory_already_exists
test_should_report_unknown_language_and_still_create_generic_template
```

**DI seam**: Inject the detector and writer (or their results) so the
orchestrator test never touches the filesystem.

### Integration Tests

One integration test per supported template that exercises the full flow
in a tmpdir with real files:

```
test_should_create_working_ruby_bundler_project_from_gemfile
test_should_create_working_jvm_gradle_project_from_build_gradle_kts
test_should_create_working_jvm_maven_project_from_pom_xml
```

These tests create a tmpdir with the right marker file, call the full
Installer, and verify `.fun-ci/` was created with executable scripts
containing the right commands. These are the tests that catch wiring
bugs between detector and writer.

### Acceptance Tests

A single acceptance test per template that exercises the CLI entry point
end-to-end. Model this on `TriggerCliClient` -- create an
`InstallerCliClient` that:

- Creates a tmpdir with marker files
- Invokes the CLI (or the `run_from_args` equivalent)
- Captures stdout/stderr and exit code
- Provides query methods for the generated files

```
test_should_create_executable_scripts_for_ruby_project
test_should_report_what_was_created_to_stdout
test_should_exit_gracefully_when_fun_ci_already_exists
```

**Pattern to follow**: `TriggerCliClient` in
`test/acceptance/trigger_cli_client.rb`. It wraps the real entry point,
captures I/O, and provides intent-revealing query methods. The installer
client should do the same.

---

## Feature 2: `fun-ci install-hook`

### What It Does

1. Accepts a hook type argument: `pre-commit` or `pre-push`.
2. Writes a git hook script to `.git/hooks/<hook-type>`.
3. Makes it executable.
4. The hook script calls `fun-ci trigger` with the right arguments.

### The Git Repo Question

This feature needs a `.git/` directory. We have two options:

**Option A: Real `git init` in tmpdir.**
```ruby
Dir.mktmpdir do |dir|
  system("git", "init", dir)
  # now .git/hooks/ exists
end
```

This is deterministic, fast (< 50ms), and creates the exact directory
structure we need. `git init` is a pure local operation with no network,
no config, no side effects outside the tmpdir.

**Option B: Fake the `.git/hooks/` directory manually.**
```ruby
Dir.mktmpdir do |dir|
  FileUtils.mkdir_p(File.join(dir, ".git", "hooks"))
end
```

Simpler, no git dependency in tests, but we lose confidence that the
hook will actually work in a real git repo.

**Recommendation: Use Option A for integration/acceptance tests, Option B
for unit tests.** The unit test for the hook writer only needs to verify
file creation and permissions. The integration test should use a real git
init to catch path assumptions.

### Unit Tests

The hook writer is a simple class: given a project root and hook type,
write a file with specific content to a specific path.

```
test_should_write_pre_commit_hook_script
test_should_write_pre_push_hook_script
test_should_make_hook_script_executable
test_should_reject_unknown_hook_type
test_should_not_overwrite_existing_hook_without_marker
```

**DI seam**: The hook writer does not need any DI beyond what tmpdir
provides. It is pure filesystem work. No lambdas needed.

**Pitfall: Preserving existing hooks.** If the user already has a
pre-commit hook (from husky, overcommit, etc.), blindly overwriting it
will make them very unhappy. The hook writer should:
1. Check if the hook file exists.
2. If it exists, check for a fun-ci marker comment.
3. If the marker is present, overwrite (it is ours).
4. If no marker, refuse and tell the user.

This means the generated hook script must contain a recognizable marker
comment, e.g. `# fun-ci-managed-hook`. Test for this marker in the
generated content.

```
test_should_include_marker_comment_in_generated_hook
test_should_overwrite_when_existing_hook_has_marker
test_should_refuse_when_existing_hook_has_no_marker
```

**Pitfall: Hook script content.** The hook needs to know how to invoke
fun-ci trigger. For a pre-commit hook, it needs to extract the commit
hash and branch. Pre-commit hooks run before the commit exists, so the
script needs to handle this differently from pre-push. Think carefully
about what the hook script actually does -- this is where bugs will hide.

Assert structurally:
```ruby
content = File.read(hook_path)
assert_match(/fun-ci.*trigger/, content, "Should call fun-ci trigger")
assert_match(/# fun-ci-managed-hook/, content, "Should include marker")
```

### Integration Tests

```
test_should_install_pre_commit_hook_into_real_git_repo
test_should_install_pre_push_hook_into_real_git_repo
```

Use `git init` in tmpdir. Verify the hook file lands in the right place
and has the right permissions.

### Acceptance Tests

```
test_should_install_hook_and_report_success
test_should_refuse_when_not_in_a_git_repo
test_should_refuse_when_hook_already_exists_from_another_tool
```

---

## Feature 3: `fun-ci check`

### What It Does

1. Validates `.fun-ci/` exists.
2. Validates all four scripts exist and are executable.
3. Validates the git hook is installed.
4. Reports status to stdout.

### Key Insight: Reuse ProjectConfig

`ProjectConfig` already validates `.fun-ci/` and the four scripts. The
`check` command should use `ProjectConfig#validate` for that part and add
hook validation on top. Do NOT duplicate the validation logic.

### Unit Tests

If the check command is thin orchestration over ProjectConfig + a hook
checker, unit tests are minimal:

```
test_should_report_all_clear_when_everything_is_configured
test_should_report_missing_fun_ci_folder
test_should_report_missing_scripts
test_should_report_non_executable_scripts
test_should_report_missing_git_hook
test_should_report_multiple_issues_at_once
```

**DI seam**: Inject a config validator and a hook checker (or their
results). The check command itself is pure: it takes validation results
and formats output.

**Alternative**: If the check command is simple enough (call
ProjectConfig#validate, check for hook file, print results), it may not
warrant a separate unit test class. The integration test may be
sufficient. Evaluate this during implementation -- do not create classes
just to have something to unit-test.

### Integration Tests

```
test_should_pass_when_project_is_fully_configured
test_should_fail_when_fun_ci_folder_is_missing
test_should_fail_when_hook_is_not_installed
test_should_report_all_issues_found
```

These use tmpdir with varying levels of setup completeness. The
fully-configured test uses `git init` + `make_project_with_scripts` +
hook installation.

### Acceptance Tests

```
test_should_report_clean_status_for_fully_configured_project
test_should_report_actionable_errors_for_unconfigured_project
```

---

## Cross-Cutting Concerns

### CLI Entry Point Design

Right now the project has two executables: `exe/fun-ci-trigger` and
`exe/fun-ci-tui`. The installer features suggest a unified CLI:

```
fun-ci init
fun-ci install-hook pre-commit
fun-ci check
fun-ci trigger <hash> <branch>   (existing)
```

This means either a dispatcher in `exe/fun-ci` or separate executables.
Either way, the test strategy is the same: test each command's class
independently, and have acceptance tests that go through the CLI entry
point.

If building a dispatcher, it is a simple class with its own unit test:

```
test_should_dispatch_init_to_installer
test_should_dispatch_check_to_checker
test_should_dispatch_install_hook_to_hook_installer
test_should_dispatch_trigger_to_trigger
test_should_print_usage_when_unknown_command
```

**Pitfall: Do not entangle the dispatcher with any command's logic.**
The dispatcher routes to commands. Commands do work. Mixing these makes
both harder to test.

### Test File Organization

Following the existing convention:

```
test/
  unit/
    test_project_detector.rb      # Pure logic, no I/O
    test_template_writer.rb       # tmpdir, structural assertions
    test_hook_writer.rb           # tmpdir, file creation
    test_setup_checker.rb         # Orchestration over config + hook
  integration/
    test_installer.rb             # Full init flow in tmpdir
    test_hook_installation.rb     # git init + hook write in tmpdir
    test_check_command.rb         # Various states in tmpdir
  acceptance/
    test_init_cli.rb              # End-to-end via CLI
    test_install_hook_cli.rb      # End-to-end via CLI
    test_check_cli.rb             # End-to-end via CLI
    installer_cli_client.rb       # Client abstraction (like trigger_cli_client.rb)
```

**Keep files under 150 lines.** The acceptance client might need splitting
if it grows (like `trigger_cli_client.rb` at 179 lines -- already close
to the limit).

### Shared Test Infrastructure

Extend `FunCiTestProject` in `test_helper.rb`:

```ruby
module FunCiTestProject
  # Existing method
  def make_project_with_scripts(dir)
    # ...
  end

  # New: create a project that looks like a Ruby+Bundler project
  def make_ruby_project(dir)
    File.write(File.join(dir, "Gemfile"), "source 'https://rubygems.org'\n")
  end

  # New: create a project that looks like a Gradle Kotlin project
  def make_gradle_kotlin_project(dir)
    File.write(File.join(dir, "build.gradle.kts"), "plugins { kotlin(\"jvm\") }\n")
  end

  # New: create a project that looks like a Maven project
  def make_maven_project(dir)
    File.write(File.join(dir, "pom.xml"), "<project></project>\n")
  end

  # New: set up a git repo in a tmpdir
  def make_git_repo(dir)
    system("git", "init", "--quiet", dir)
  end
end
```

These helpers should create the minimal marker files needed for detection.
They do NOT need to be real, buildable projects -- just enough for the
detector to identify them.

### Template Registry Pattern

Templates should be data, not code. A simple hash mapping template
identifiers to script content strings:

```ruby
TEMPLATES = {
  ruby_bundler: {
    "lint.sh"  => "#!/bin/sh\nbundle exec rubocop\n",
    "build.sh" => "#!/bin/sh\nbundle install --quiet\n",
    "fast.sh"  => "#!/bin/sh\nbundle exec rake test\n",
    "slow.sh"  => "#!/bin/sh\nbundle exec rake test:slow\n"
  },
  jvm_gradle_kotlin: { ... },
  # ...
}
```

This makes testing trivial: verify the registry contains the expected
keys and that each template has all four scripts. No filesystem needed.

```
test_should_have_template_for_each_supported_stack
test_should_include_all_four_scripts_in_each_template
test_should_have_shebang_in_every_script
```

### InstallerCliClient Design

Model on `TriggerCliClient`. Key methods:

```ruby
class InstallerCliClient
  attr_reader :exit_code, :stdout, :stderr, :project_dir

  def initialize
    @project_dir = Dir.mktmpdir("fun-ci-installer-test")
  end

  def close
    FileUtils.remove_entry(@project_dir) rescue nil
  end

  # Set up a Ruby project and run init
  def init_ruby_project
    File.write(File.join(@project_dir, "Gemfile"), "source 'https://rubygems.org'\n")
    run_init
  end

  # Query the generated scripts
  def script_content(name)
    path = File.join(@project_dir, ".fun-ci", name)
    File.exist?(path) ? File.read(path) : nil
  end

  def script_executable?(name)
    path = File.join(@project_dir, ".fun-ci", name)
    File.exist?(path) && File.executable?(path)
  end

  def fun_ci_exists?
    Dir.exist?(File.join(@project_dir, ".fun-ci"))
  end

  private

  def run_init
    stdout_io = StringIO.new
    stderr_io = StringIO.new
    # Call the Installer class directly, like TriggerCliClient calls Trigger
    @exit_code = FunCi::Installer.run(
      project_root: @project_dir,
      stdout: stdout_io,
      stderr: stderr_io
    )
    @stdout = stdout_io.string
    @stderr = stderr_io.string
  end
end
```

---

## Potential Pitfalls (Lessons from This Codebase)

### 1. Parallel test safety with tmpdir

This project runs tests in parallel via `ActiveSupport::Testing::ParallelizeExecutor`
with `:processes`. Every test that creates files must use its own tmpdir.
Never use a shared path. The existing tests already do this correctly
(every test block uses `Dir.mktmpdir`), and the installer tests should
follow the same pattern.

Watch out for `git init` in parallel tests -- each test gets its own
tmpdir, so this is safe. But if any test tries to use the real working
directory's `.git/`, tests will interfere with each other and with the
actual repository.

### 2. Do not test template contents with exact string equality

Templates will evolve. Comments will change. Commands will be tweaked.
If tests assert on exact file contents, every template edit breaks tests.
Use structural assertions (shebang, key command, `$1` reference).

### 3. The chmod 0o755 pattern is already proven

The codebase uses `File.chmod(0o755, path)` in `FunCiTestProject` and
tests executability in `test_project_config.rb`. Reuse this exact pattern.
Do not invent a new way to set/check permissions.

### 4. No production if-statements for test purposes

If the detector or writer needs different behavior in tests, use DI, not
conditionals. For example, if the detector needs to scan the filesystem,
inject the file list rather than adding `if ENV['TEST']` guards.

### 5. The stdout/stderr pattern is established

Every class that outputs to the user accepts `stdout:` and `stderr:` as
constructor arguments, defaulting to `$stdout` and `$stderr`. The
installer classes should follow this same convention. Tests inject
`StringIO.new` instances.

### 6. `FunCiTestProject` could become a dumping ground

The existing module has one method (`make_project_with_scripts`). Adding
`make_ruby_project`, `make_gradle_project`, etc. could bloat it. If it
grows beyond 5-6 methods, consider splitting into `FunCiTestProject` (for
`.fun-ci/` setup) and `FunCiTestDetection` (for marker file setup).

### 7. Be careful with `Dir.children` vs `Dir.entries`

`Dir.children` excludes `.` and `..`. `Dir.entries` includes them. The
detector should use `Dir.children` (or better, accept an explicit list).
A test that passes `Dir.entries` results would include `.` and `..` in
the filename list, which could confuse detection logic.

### 8. Hook script content is tricky

The pre-commit hook runs before the commit is created. The commit hash
is not yet available. The hook needs to use `$(git rev-parse HEAD)` or
similar to get the current state. For pre-push, the hook receives refs
on stdin. Getting this wrong means fun-ci trigger gets called with the
wrong arguments. Test the hook script content structurally to catch these
issues.

### 9. init should work without git

A user might run `fun-ci init` before `git init`. The init command should
create `.fun-ci/` regardless of whether `.git/` exists. Do not couple
init to git presence. Only `install-hook` and `check` (when checking the
hook) need git.

---

## Suggested Test Sequence (ATDD Order)

Start with the simplest end-to-end behavior and work inward.

### Cycle 1: `fun-ci check` on an unconfigured project
- Acceptance: check reports "no .fun-ci/ folder"
- Unit: thin wrapper over ProjectConfig#validate (already exists)
- This is the simplest feature -- mostly reuses existing code.

### Cycle 2: `fun-ci init` for Ruby+Bundler
- Acceptance: init creates `.fun-ci/` with executable scripts
- Unit: ProjectDetector detects Ruby from Gemfile
- Unit: TemplateWriter writes scripts and sets permissions
- Integration: full flow creates correct Ruby template

### Cycle 3: `fun-ci check` on a configured project
- Acceptance: check reports "all good" after init
- This connects init and check together.

### Cycle 4: `fun-ci install-hook pre-commit`
- Acceptance: install-hook creates executable hook in `.git/hooks/`
- Unit: HookWriter creates file with marker and correct content
- Integration: hook lands in real git repo

### Cycle 5: `fun-ci check` with hook validation
- Acceptance: check detects missing hook, reports it
- Extends cycle 1/3 with hook checking.

### Cycle 6: Additional templates (Gradle, Maven)
- Unit: ProjectDetector detects each stack
- Unit: Template registry contains all templates
- Integration: each template generates correct scripts

This sequence builds each feature incrementally, with each cycle
producing a working, tested slice. The check command is tested first
because it is the simplest and validates the setup that init creates.
