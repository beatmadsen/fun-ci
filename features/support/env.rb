# frozen_string_literal: true

# Cucumber support file for fun-ci Admin TUI acceptance tests
#
# Sets up an acceptance test client that hides TUI interaction
# details behind a clean, intent-revealing API.

require "minitest"
require "tmpdir"
require "stringio"
require "time"

$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "fun_ci"
require "fun_ci/tui/admin_tui"
require "fun_ci/tui/ansi"

require_relative "../../test/support/confinement_guard"
require_relative "minitest_world"
require_relative "tui_test_client"

World(MinitestWorld)
ConfinementGuard.install

Before do
  @client = TuiTestClient.new
end

# Quitting also proves every scenario leaves the run loop able to exit.
After do
  @client.stop_run_loop
ensure
  @client.cleanup
end
