# frozen_string_literal: true

require_relative "shell"

module FunCi
  module Setup
    # Stacks that compile to the machine: Rust, Go, Swift, and C or C++ built
    # with CMake or make.
    module StageTemplates
      CTEST = "ctest --test-dir build --output-on-failure --no-tests=error"
      CLANG_FORMAT = "git ls-files -z '*.c' '*.cc' '*.cpp' '*.h' '*.hpp' | xargs -0 clang-format --dry-run --Werror"

      NATIVE = {
        rust_cargo: stages("cargo clippy --all-targets -- -D warnings", "cargo build --all-targets",
                           "cargo test", "cargo test -- --ignored"),
        go: stages("go vet ./...", "go build ./...", "go test -short ./...", "go test ./..."),
        swift: stages("swift format lint --recursive --strict .", "swift build --build-tests",
                      "swift test --skip-build --skip Slow", "swift test --skip-build --filter Slow"),
        cmake: stages(CLANG_FORMAT, "cmake -S . -B build && cmake --build build",
                      "#{CTEST} -LE slow", "#{CTEST} -L slow"),
        make: stages("make lint", "make", "make test", "make test-slow")
      }.freeze
    end
  end
end
