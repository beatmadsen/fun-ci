# Stacks and presets

This page lists what fun-ci knows about each stack: how `fun-ci init` recognises it, the four stage scripts it writes, and the presets that pick a tool's failures out of a failed stage's output. `ruby script/stacks_doc.rb` draws it from the code, and a test fails when the two disagree, so change the code and run the script rather than editing the page.

## What `fun-ci init` writes

`fun-ci init` looks at the names at the top of your project and takes the first stack in this table that has one of its markers there. A Python project with a `package.json` for its front end is set up as Python, and a Go project with a `Makefile` as Go. The scripts are plain shell and a starting point, so edit them to run whatever your project uses.

The fast suite leaves out the tests the tool's own convention marks slow, and the slow suite runs only those (for Maven, failsafe's integration tests, the classes named `*IT`). Where the tool has no such convention, the slow suite is a `test:slow` script (a `test-slow` target for make). A slow suite with no tests in it passes having run nothing under cargo, dotnet, Maven, PHPUnit, rspec and swift, and fails under the others, until you edit `slow.sh`.

| Stack | Detected by | lint.sh | build.sh | fast.sh | slow.sh |
| --- | --- | --- | --- | --- | --- |
| Ruby (rspec) | `Gemfile` and `spec` or `Gemfile` and `.rspec` | `bundle exec rubocop` | `bundle install --quiet` | `bundle exec rspec --tag ~slow` | `bundle exec rspec --tag slow` |
| Ruby (rake) | `Gemfile` | `bundle exec rubocop` | `bundle install --quiet` | `bundle exec rake test` | `bundle exec rake test:slow` |
| Gradle (Kotlin DSL) | `build.gradle.kts` or `settings.gradle.kts` | `./gradlew check -x test` | `./gradlew assemble testClasses` | `./gradlew test` | `./gradlew integrationTest` |
| Gradle (Groovy DSL) | `build.gradle` or `settings.gradle` | `./gradlew check -x test` | `./gradlew assemble testClasses` | `./gradlew test` | `./gradlew integrationTest` |
| Maven | `pom.xml` | `mvn verify -DskipTests` | `mvn test-compile` | `mvn surefire:test` | `mvn failsafe:integration-test failsafe:verify` |
| Rust | `Cargo.toml` | `cargo clippy --all-targets -- -D warnings` | `cargo build --all-targets` | `cargo test` | `cargo test -- --ignored` |
| Go | `go.mod` | `go vet ./...` | `go build ./...` | `go test -short ./...` | `go test ./...` |
| Elixir | `mix.exs` | `mix format --check-formatted` | `mix deps.get && MIX_ENV=test mix compile` | `mix test --exclude slow` | `mix test --only slow` |
| Dart | `pubspec.yaml` | `dart analyze` | `dart pub get --precompile` | `dart test --exclude-tags slow` | `dart test --compiler source --tags slow` |
| Swift | `Package.swift` | `swift format lint --recursive --strict .` | `swift build --build-tests` | `swift test --skip-build --skip Slow` | `swift test --skip-build --filter Slow` |
| PHP | `composer.json` | `vendor/bin/phpcs` | `composer install --no-interaction --no-progress` | `vendor/bin/phpunit --exclude-group slow` | `vendor/bin/phpunit --group slow` |
| .NET | `*.sln` or `*.csproj` or `*.fsproj` | `dotnet format --verify-no-changes` | `dotnet build` | `dotnet test --no-build --filter "Category!=Slow"` | `dotnet test --no-build --filter "Category=Slow"` |
| Python (uv) | `uv.lock` | `uv run ruff check .` | `uv sync` | `uv run pytest -m "not slow"` | `uv run pytest -m slow` |
| Python (Poetry) | `poetry.lock` | `poetry run ruff check .` | `poetry install` | `poetry run pytest -m "not slow"` | `poetry run pytest -m slow` |
| Python (pip) | `pyproject.toml` or `setup.py` or `setup.cfg` or `requirements.txt` | `python3 -m ruff check .` | `python3 -m compileall -q .` | `python3 -m pytest -m "not slow"` | `python3 -m pytest -m slow` |
| Deno | `deno.json` or `deno.jsonc` | `deno lint` | `deno check` | `deno test` | `deno task test:slow` |
| Bun | `bun.lock` or `bun.lockb` or `bunfig.toml` | `bunx eslint .` | `bun install` | `bun test` | `bun run test:slow` |
| Node (pnpm) | `pnpm-lock.yaml` | `pnpm exec eslint .` | `pnpm install` | `pnpm test` | `pnpm run test:slow` |
| Node (Yarn) | `yarn.lock` | `yarn eslint .` | `yarn install` | `yarn test` | `yarn run test:slow` |
| Node (npm) | `package.json` | `npx eslint .` | `npm install` | `npm test` | `npm run test:slow` |
| Perl | `cpanfile` or `Makefile.PL` or `Build.PL` or `dist.ini` | `perlcritic lib` | `cpanm --installdeps --notest .` | `prove -lr t` | `prove -lr xt` |
| C and C++ (CMake) | `CMakeLists.txt` | `git ls-files -z '*.c' '*.cc' '*.cpp' '*.h' '*.hpp' \| xargs -0 clang-format --dry-run --Werror` | `cmake -S . -B build && cmake --build build` | `ctest --test-dir build --output-on-failure --no-tests=error -LE slow` | `ctest --test-dir build --output-on-failure --no-tests=error -L slow` |
| C and C++ (make) | `Makefile` or `makefile` or `GNUmakefile` | `make lint` | `make` | `make test` | `make test-slow` |

## Presets

When a stage fails, fun-ci runs the presets that apply, with no configuration. A preset applies when the project has one of its marker files (or the preset has none) and the stage's output has a line only its tool prints. Each is checked against the recorded output of a real failing run of its tool, kept in `test/fixtures/evidence/`. `fun-ci check` lists the presets that apply to your project and `fun-ci why` says why each one ran. To keep more than the presets pick out, add entries under `evidence:` in `.fun-ci/config`, as the README shows.

| Preset | Picks out | Stack | Runs in a project with any of |
| --- | --- | --- | --- |
| `bun-test` | Bun's failed tests | Bun | `bun.lockb`, `bun.lock`, `bunfig.toml` |
| `cargo-test` | cargo test's failed tests | Rust | `Cargo.toml` |
| `dart-test` | dart test's failures | Dart | `pubspec.yaml` |
| `deno-test` | Deno's failing tests | Deno | `deno.json`, `deno.jsonc` |
| `dotnet-test` | dotnet test's failed tests | .NET | `*.sln`, `*.csproj`, `*.fsproj` |
| `ecs` | Log records at warn or above | Any | Any project |
| `eslint` | ESLint's problems, file by file | Node | `eslint.config.js`, `eslint.config.mjs`, `.eslintrc.json`, `.eslintrc.js` |
| `exunit` | ExUnit's failures | Elixir | `mix.exs` |
| `gcc` | gcc's errors, file by file | C and C++ | `Makefile`, `makefile`, `GNUmakefile`, `CMakeLists.txt` |
| `go-build` | go build's and go vet's errors | Go | `go.mod` |
| `go-test` | go test's failed tests | Go | `go.mod` |
| `gradle` | Gradle's failed tests, and what went wrong | Gradle | `build.gradle`, `build.gradle.kts`, `settings.gradle`, `settings.gradle.kts`, `gradlew` |
| `gtest` | GoogleTest's failures | C and C++ | `CMakeLists.txt` holding `gtest` |
| `jest` | Jest's failed tests | Node | `package.json` holding `"jest"`, `jest.config.js`, `jest.config.ts`, `jest.config.mjs`, `jest.config.cjs` |
| `logstash` | Log records at warn or above | Any | Any project |
| `maven` | Maven's failed tests | Maven | `pom.xml`, `mvnw` |
| `minitest` | Minitest's failures and errors | Ruby | `Gemfile`, `Rakefile` |
| `mocha` | Mocha's failing tests | Node | `package.json` holding `"mocha"`, `.mocharc.yml`, `.mocharc.yaml`, `.mocharc.json`, `.mocharc.js`, `.mocharc.cjs` |
| `mypy` | mypy's type errors | Python | `pyproject.toml` holding `mypy`, `mypy.ini`, `.mypy.ini`, `setup.cfg` holding `mypy` |
| `node-test` | Node's failed tests | Node | `package.json` holding `node --test` |
| `phpunit` | PHPUnit's errors and failures | PHP | `phpunit.xml`, `phpunit.xml.dist`, `composer.json` holding `phpunit` |
| `pino` | Log records at warn or above | Node | `package.json` holding `"pino"` |
| `prove` | prove's failed tests | Perl | `cpanfile`, `Makefile.PL`, `Build.PL`, `dist.ini` |
| `pytest` | pytest's failures and errors | Python | `pyproject.toml`, `pytest.ini`, `setup.cfg`, `tox.ini`, `conftest.py` |
| `rspec` | rspec's failures | Ruby | `Gemfile`, `.rspec` |
| `rubocop` | RuboCop's offenses | Ruby | `.rubocop.yml`, `Gemfile` holding `rubocop` |
| `ruff` | ruff's lint errors | Python | `pyproject.toml` holding `ruff`, `ruff.toml`, `.ruff.toml`, `.pre-commit-config.yaml` holding `ruff` |
| `rustc` | rustc's errors | Rust | `Cargo.toml` |
| `shellcheck` | ShellCheck's findings | Any | Any project |
| `structlog` | Log records at warn or above | Python | `pyproject.toml` holding `structlog`, `requirements.txt` holding `structlog`, `setup.cfg` holding `structlog`, `setup.py` holding `structlog` |
| `swift-test` | XCTest's failures | Swift | `Package.swift` |
| `tsc` | TypeScript's type errors | Node | `tsconfig.json` |
| `unittest` | unittest's failures and errors | Python | `pyproject.toml`, `setup.py`, `setup.cfg`, `requirements.txt` |
| `vitest` | Vitest's failed tests | Node | `package.json` holding `"vitest"`, `vitest.config.ts`, `vitest.config.js`, `vitest.config.mts`, `vitest.config.mjs` |
